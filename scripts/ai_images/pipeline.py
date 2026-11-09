"""AI recipe photos: describe the original photo with Qwen3-VL, free the GPUs, then generate a brand-new
photo with Qwen-Image 2.1 from title + main ingredients + description (the original image is NOT fed to the
image model, so the result is a new photo, not a copy). See README.md in this folder.

Runs on Windows against the two ComfyUI instances from F:\\AI\\start_comfyui_2gpu.bat (8188 = GPU0, 8189 = GPU1).

usage:
  python pipeline.py caption  <manifest.jsonl> <work_dir> [--limit N]
  python pipeline.py generate <manifest.jsonl> <work_dir> [--limit N] [--steps 25]
  python pipeline.py all      <manifest.jsonl> <work_dir> [--limit N]

Everything is resumable: captions go to <work_dir>/captions.json, images to <work_dir>/images/<recipe_id>.png;
recipes already done are skipped, so the run can be stopped and restarted at any time.
"""
import argparse, json, os, queue, random, threading, time, urllib.parse, urllib.request, uuid

SERVERS = ["http://127.0.0.1:8188", "http://127.0.0.1:8189"]
MEDIA = r"\\wsl.localhost\Ubuntu\home\plex_server\PlateFlow\backend"  # image_url "/media/..." is relative to this

CAPTION_ASK = (
    "Describe only the FOOD in this photo so a cook could recognise the dish: what the dish is (soup, salad, skillet, etc.), "
    "each visible component with its shape, size, color and doneness (e.g. 'two whole browned sausage links', "
    "'golden broth with small cubes of orange sweet potato'), and how runny or thick it is. "
    "Do not describe the plate, table, props, camera angle, lighting or layout. One paragraph, at most 70 words, English."
)
# style the user picked (variant 5, 2026-11-09): bright, three-quarter angle, simple props
IMAGE_PROMPT = (
    "Professional food photograph of {title}, made with {ingredients}. The food: {caption} "
    "Served as one generous portion on a plate or in a bowl that suits the dish; the whole dish is visible in the frame, not cropped. "
    "Three-quarter angle, bright soft natural daylight, light neutral table, a few simple fresh props, shallow depth of field. "
    "Realistic, appetizing editorial cookbook photography, no text, no watermark."
)


# ---------------------------------------------------------------- comfy helpers
def _req(url, data=None, headers=None, timeout=60):
    return urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers or {}), timeout=timeout).read()


def post_json(server, path, body):
    raw = _req(server + path, json.dumps(body).encode(), {"Content-Type": "application/json"})
    return json.loads(raw) if raw.strip() else {}


def upload(server, path):
    b = "----pf" + uuid.uuid4().hex
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"pf_{uuid.uuid4().hex[:8]}.jpg\"\r\n"
            f"Content-Type: image/jpeg\r\n\r\n").encode() + open(path, "rb").read() + \
           f"\r\n--{b}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{b}--\r\n".encode()
    return json.loads(_req(server + "/upload/image", body, {"Content-Type": f"multipart/form-data; boundary={b}"}))["name"]


def run_prompt(server, graph):
    pid = post_json(server, "/prompt", {"prompt": graph})["prompt_id"]
    while True:
        time.sleep(2)
        h = json.loads(_req(f"{server}/history/{pid}", timeout=30))
        if pid in h:
            h = h[pid]
            if h.get("status", {}).get("status_str") == "error":
                raise RuntimeError(json.dumps(h["status"])[:1500])
            return h["outputs"]


def free_gpus():
    for s in SERVERS:
        post_json(s, "/free", {"unload_models": True, "free_memory": True})
    print("GPUs freed", flush=True)


def run_parallel(items, worker):
    """one thread per ComfyUI instance pulling from a shared queue"""
    q = queue.Queue()
    for it in items:
        q.put(it)

    def loop(server):
        while True:
            try:
                it = q.get_nowait()
            except queue.Empty:
                return
            try:
                worker(server, it)
            except Exception as e:  # keep going; the item is retried on the next run
                print("ERROR", it["id"], e, flush=True)

    ts = [threading.Thread(target=loop, args=(s,)) for s in SERVERS]
    [t.start() for t in ts]
    [t.join() for t in ts]


# ---------------------------------------------------------------- phases
def caption_phase(recipes, work):
    path = os.path.join(work, "captions.json")
    caps = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    todo = [r for r in recipes if r["id"] not in caps]
    print(f"captions: {len(caps)} done, {len(todo)} to do", flush=True)
    lock, t0 = threading.Lock(), time.time()

    def work_one(server, r):
        img = os.path.join(MEDIA, r["image_url"].lstrip("/").replace("/", os.sep))
        name = upload(server, img)
        out = run_prompt(server, {
            "1": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image", "device": "default"}},
            "2": {"class_type": "LoadImage", "inputs": {"image": name}},
            "3": {"class_type": "TextGenerate", "inputs": {"clip": ["1", 0], "prompt": CAPTION_ASK, "max_length": 256,
                                                           "sampling_mode": "off", "image": ["2", 0], "thinking": False}},
            "4": {"class_type": "PreviewAny", "inputs": {"source": ["3", 0]}},
        })
        o = out["4"]
        text = (o.get("text") or o.get("string") or [""])[0].strip()
        with lock:
            caps[r["id"]] = text
            if len(caps) % 10 == 0:
                json.dump(caps, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print(f"caption {len(caps)}/{len(recipes)} {r['title'][:50]} ({time.time() - t0:.0f}s)", flush=True)

    run_parallel(todo, work_one)
    json.dump(caps, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    free_gpus()  # unload Qwen3-VL before the image model is loaded
    return caps


def generate_phase(recipes, work, steps):
    caps_path = os.path.join(work, "captions.json")
    caps = json.load(open(caps_path, encoding="utf-8")) if os.path.exists(caps_path) else {}
    out_dir = os.path.join(work, "images")
    os.makedirs(out_dir, exist_ok=True)
    todo = [r for r in recipes if r["id"] in caps and not os.path.exists(os.path.join(out_dir, r["id"] + ".png"))]
    print(f"images: {len(todo)} to generate", flush=True)
    t0, done = time.time(), [0]

    def work_one(server, r):
        prompt = IMAGE_PROMPT.format(title=r["title"], ingredients=r.get("ingredients") or "its ingredients", caption=caps[r["id"]])
        out = run_prompt(server, {
            "1": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": "qwen-image-2.1-UC-Q8_0.gguf"}},
            "2": {"class_type": "QwenImage21Cache", "inputs": {"model": ["1", 0], "device": "auto", "dtype": "default"}},
            "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image", "device": "default"}},
            "4": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
            "6": {"class_type": "TextEncodeQwenImage21", "inputs": {"clip": ["3", 0], "prompt": prompt, "negative_prompt": "",
                                                                    "resolution": 1024, "vae": ["4", 0]}},
            "10": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
            "7": {"class_type": "KSampler", "inputs": {"model": ["2", 0], "positive": ["6", 0], "negative": ["6", 1],
                                                       "latent_image": ["10", 0], "seed": random.randint(1, 2**48), "steps": steps,
                                                       "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
            "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["4", 0]}},
            "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "plateflow_ai"}},
        }, )
        img = out["9"]["images"][0]
        q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
        open(os.path.join(out_dir, r["id"] + ".png"), "wb").write(_req(f"{server}/view?{q}"))
        done[0] += 1
        rate = (time.time() - t0) / done[0]
        print(f"image {done[0]}/{len(todo)} {r['title'][:50]} (~{rate * (len(todo) - done[0]) / 3600:.1f}h left)", flush=True)

    run_parallel(todo, work_one)
    free_gpus()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("phase", choices=["caption", "generate", "all"])
    ap.add_argument("manifest")
    ap.add_argument("work")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--steps", type=int, default=25)
    a = ap.parse_args()
    for s in SERVERS:
        try:
            _req(s + "/system_stats", timeout=5)
        except Exception:
            raise SystemExit(f"ComfyUI is not running at {s} - start F:\\AI\\start_comfyui_2gpu.bat first")
    os.makedirs(a.work, exist_ok=True)
    recipes = [json.loads(l) for l in open(a.manifest, encoding="utf-8") if l.strip()]
    if a.limit:
        recipes = recipes[:a.limit]
    if a.phase in ("caption", "all"):
        caption_phase(recipes, a.work)
    if a.phase in ("generate", "all"):
        generate_phase(recipes, a.work, a.steps)
