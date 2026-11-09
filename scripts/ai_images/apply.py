"""Put generated photos into the app: <work>/images/<id>.png -> backend/media/recipes/<id>-ai.jpg and write
<work>/apply.sql that points recipes.image_url at them (plus <work>/revert.sql that restores the old urls).
The original files are left untouched, so reverting is just running revert.sql.

usage (ComfyUI venv has Pillow):  F:\\AI\\ComfyUI\\venv\\Scripts\\python.exe apply.py <manifest.jsonl> <work_dir>
then:  docker compose exec -T db psql -U <user> -d <db> < <work_dir>/apply.sql
"""
import json, os, sys

from PIL import Image

MEDIA = r"\\wsl.localhost\Ubuntu\home\plex_server\PlateFlow\backend\media\recipes"
manifest, work = sys.argv[1:3]
recipes = {r["id"]: r for r in (json.loads(l) for l in open(manifest, encoding="utf-8") if l.strip())}
apply_sql, revert_sql = ["begin;"], ["begin;"]
for f in sorted(os.listdir(os.path.join(work, "images"))):
    rid = f.rsplit(".", 1)[0]
    if rid not in recipes:
        continue
    out = f"{rid}-ai.jpg"
    Image.open(os.path.join(work, "images", f)).convert("RGB").save(os.path.join(MEDIA, out), quality=88, optimize=True)
    apply_sql.append(f"update recipes set image_url = '/media/recipes/{out}' where id = '{rid}';")
    revert_sql.append(f"update recipes set image_url = '{recipes[rid]['image_url']}' where id = '{rid}';")
apply_sql.append("commit;")
revert_sql.append("commit;")
open(os.path.join(work, "apply.sql"), "w").write("\n".join(apply_sql) + "\n")
open(os.path.join(work, "revert.sql"), "w").write("\n".join(revert_sql) + "\n")
print(f"{len(apply_sql) - 2} photos ready; run apply.sql to switch, revert.sql to go back")
