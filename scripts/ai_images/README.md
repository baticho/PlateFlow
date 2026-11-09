# AI recipe photos

Replaces the imported (Mealime) recipe photos with brand-new AI photos of the same dish.
Picked on 2026-11-09 after comparing 5 variants (img2img edits stayed too close to the originals;
ingredients-only got some dishes wrong). The chosen flow, "variant 5":

1. **Describe** – Qwen3-VL looks at the original photo and writes a short description of the *food only*
   (dish type, components, colors, doneness – no plate/props/layout).
2. **Free the GPUs** – both ComfyUI instances unload the VL model (`POST /free`).
3. **Generate** – Qwen-Image 2.1 (GGUF Q8) makes a new 1024×1024 photo from
   *title + main ingredients + description*. The original image is not given to the image model,
   so the result is a new photo, not a copy. Style: bright daylight, three-quarter angle, light neutral
   table, simple props, whole dish in frame.
4. **Apply** – convert to JPG next to the originals and switch `recipes.image_url` (revertable).

## Requirements
- Windows PC, `F:\AI\start_comfyui_2gpu.bat` running (ComfyUI on 8188 = GPU0 and 8189 = GPU1).
- Models in `F:\AI\ComfyUI\models`: `diffusion_models/qwen-image-2.1-UC-Q8_0.gguf`,
  `text_encoders/qwen3vl_8b_int8_convrot.safetensors`, `vae/qwen_image_2.1_vae_bf16.safetensors`.

## Run
```bash
# 1. manifest (WSL, in ~/PlateFlow)
U=$(docker compose exec -T db printenv POSTGRES_USER | tr -d '\r'); D=$(docker compose exec -T db printenv POSTGRES_DB | tr -d '\r')
docker compose exec -T db psql -U "$U" -d "$D" -At < scripts/ai_images/manifest.sql > scripts/ai_images/work/manifest.jsonl
```
```powershell
# 2+3. describe all, free GPUs, generate all (Windows). Resumable: stop/restart any time.
$s="\\wsl.localhost\Ubuntu\home\plex_server\PlateFlow\scripts\ai_images"
python "$s\pipeline.py" all "$s\work\manifest.jsonl" "$s\work"            # add --limit 10 for a test
# 4. jpgs + apply.sql / revert.sql
F:\AI\ComfyUI\venv\Scripts\python.exe "$s\apply.py" "$s\work\manifest.jsonl" "$s\work"
```
```bash
docker compose exec -T db psql -U "$U" -d "$D" < scripts/ai_images/work/apply.sql    # revert.sql to undo
```

## Timing (2× RTX 3060)
- Describe: a few seconds per photo.
- Generate: ~100–130 s per photo per GPU → ~1837 recipes ≈ 26–33 h with both GPUs.

`work/` (manifest, captions, generated images) is not meant to be committed.
