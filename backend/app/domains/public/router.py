"""Public, unauthenticated endpoints: recipe share pages, APK download, Android App Links, app version."""
import json
import uuid
from html import escape
from pathlib import Path
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.domains.recipes.models import RecipeStatus
from app.domains.recipes.service import get_recipe_by_id
from app.middleware.i18n import current_language

router = APIRouter()

APK_DIR = Path(__file__).resolve().parents[3] / "media" / "apk"
APK_FILE = APK_DIR / "plateflow.apk"
VERSION_FILE = APK_DIR / "version.json"


def _apk_url() -> str:
    return f"{settings.PUBLIC_BASE_URL}/download/plateflow.apk"


@router.get("/.well-known/assetlinks.json", include_in_schema=False)
async def assetlinks():
    """Lets Android verify that https://<host>/r/... links may open the PlateFlow app directly."""
    return JSONResponse([{
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
            "namespace": "android_app",
            "package_name": settings.ANDROID_PACKAGE,
            "sha256_cert_fingerprints": [settings.ANDROID_CERT_SHA256],
        },
    }])


@router.get("/download/plateflow.apk", include_in_schema=False)
async def download_apk():
    if not APK_FILE.exists():
        raise HTTPException(status_code=404, detail="APK not published yet")
    return FileResponse(APK_FILE, media_type="application/vnd.android.package-archive", filename="PlateFlow.apk")


@router.get("/api/v1/app/version", tags=["App"])
async def app_version():
    """Latest published Android build; the app compares version_code with its own to offer an update."""
    if not VERSION_FILE.exists() or not APK_FILE.exists():
        return {"version_code": 0, "version_name": None, "apk_url": None}
    data = json.loads(VERSION_FILE.read_text())
    return {**data, "apk_url": _apk_url(), "size_bytes": APK_FILE.stat().st_size}


# --- recipe share page ----------------------------------------------------------------------------

TEXT = {
    "en": {
        "open": "Open in PlateFlow", "get": "Get the app", "ingredients": "Ingredients", "min": "min",
        "servings": "servings", "kcal": "kcal per serving",
        "teaser": "The step-by-step method, portions and shopping list are in the PlateFlow app.",
        "install_hint": "Android will ask you to allow installing apps from this source.",
        "missing": "This recipe is not available.",
    },
    "bg": {
        "open": "Отвори в PlateFlow", "get": "Изтегли приложението", "ingredients": "Съставки", "min": "мин",
        "servings": "порции", "kcal": "kcal на порция",
        "teaser": "Стъпките, порциите и списъкът за пазаруване са в приложението PlateFlow.",
        "install_hint": "Android ще поиска разрешение да инсталира приложения от този източник.",
        "missing": "Тази рецепта не е налична.",
    },
}


def _pick(translations, lang, attr):
    tr = next((t for t in translations if t.language_code == lang), None) or \
        next((t for t in translations if t.language_code == "en"), None)
    return getattr(tr, attr) if tr else ""


def _qty(q: float, unit: str) -> str:
    q = float(q)
    num = str(int(q)) if q == int(q) else f"{q:.2f}".rstrip("0").rstrip(".")
    return f"{num} {unit}".strip()


PAGE = """<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · PlateFlow</title>
<meta property="og:type" content="article">
<meta property="og:site_name" content="PlateFlow">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:image" content="{image}">
<meta property="og:url" content="{url}">
<meta name="twitter:card" content="summary_large_image">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Lora:wght@600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root {{ --paper:#FBF8F3; --ink:#221E1A; --muted:#6E655B; --line:#E6DED3; --accent:#B4532A; --card:#fff; }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --paper:#16130F; --ink:#EEE7DD; --muted:#B5AA9C; --line:#3A322A; --accent:#E58B62; --card:#221D18; }}
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--paper); color:var(--ink); font:16px/1.5 Inter, system-ui, sans-serif; }}
  main {{ max-width:560px; margin:0 auto; padding:0 0 40px; }}
  .hero {{ width:100%; aspect-ratio:4/3; object-fit:cover; display:block; background:var(--line); }}
  .body {{ padding:20px 20px 0; }}
  .brand {{ font:700 18px Lora, Georgia, serif; color:var(--ink); text-decoration:none; }}
  .brand b {{ color:var(--accent); }}
  h1 {{ font:600 28px/1.2 Lora, Georgia, serif; margin:14px 0 8px; }}
  .meta {{ color:var(--muted); font-size:14px; margin-bottom:20px; }}
  .btn {{ display:block; text-align:center; padding:14px 18px; border-radius:10px; font-weight:600; text-decoration:none; margin:10px 0; }}
  .primary {{ background:var(--accent); color:#fff; }}
  .secondary {{ border:1px solid var(--line); color:var(--ink); background:var(--card); }}
  .hint {{ color:var(--muted); font-size:12px; text-align:center; margin:4px 0 0; }}
  h2 {{ font:600 20px Lora, Georgia, serif; margin:28px 0 8px; }}
  ul {{ list-style:none; padding:0; margin:0; border-top:1px solid var(--line); }}
  li {{ display:flex; justify-content:space-between; gap:16px; padding:10px 0; border-bottom:1px solid var(--line); }}
  li span:last-child {{ color:var(--muted); white-space:nowrap; }}
  .teaser {{ margin-top:22px; padding:16px; border:1px solid var(--line); border-radius:14px; background:var(--card); color:var(--muted); font-size:14px; }}
</style>
</head>
<body>
<main>
  {hero}
  <div class="body">
    <a class="brand" href="{base}">PlateFlow<b>.</b></a>
    <h1>{title}</h1>
    <div class="meta">{meta}</div>
    <a class="btn primary" href="{intent}">{t_open}</a>
    <a class="btn secondary" href="{apk}">{t_get}</a>
    <p class="hint">{t_hint}</p>
    {ingredients}
    <div class="teaser">{t_teaser}</div>
  </div>
</main>
</body>
</html>"""


@router.get("/r/{recipe_id}", response_class=HTMLResponse, include_in_schema=False)
async def recipe_share_page(recipe_id: str, request: Request, db: AsyncSession = Depends(get_db)):
    lang = current_language.get()
    tx = TEXT.get(lang, TEXT["en"])
    try:
        rid = uuid.UUID(recipe_id)
    except ValueError:
        rid = None
    recipe = await get_recipe_by_id(db, rid) if rid else None
    if not recipe or recipe.status != RecipeStatus.PUBLISHED:
        return HTMLResponse(f"<!doctype html><meta charset=utf-8><p style='font-family:sans-serif;padding:24px'>"
                            f"{escape(tx['missing'])}</p>", status_code=404)

    base = settings.PUBLIC_BASE_URL
    url = f"{base}/r/{recipe.id}"
    title = _pick(recipe.translations, lang, "title")
    image = f"{base}{recipe.image_url}" if recipe.image_url and recipe.image_url.startswith("/") else (recipe.image_url or "")
    meta_parts = [f"{recipe.total_time_minutes} {tx['min']}", f"{recipe.servings} {tx['servings']}"]
    if recipe.calories is not None:
        meta_parts.append(f"{round(float(recipe.calories))} {tx['kcal']}")
    meta = " · ".join(meta_parts)

    items = []
    for ri in recipe.ingredients:
        name = _pick(ri.ingredient.translations, lang, "name") if ri.ingredient else ""
        items.append(f"<li><span>{escape(name[:1].upper() + name[1:])}</span><span>{escape(_qty(ri.quantity, ri.unit))}</span></li>")
    ingredients = f"<h2>{escape(tx['ingredients'])}</h2><ul>{''.join(items)}</ul>" if items else ""

    # Android: open the installed app; otherwise fall back to downloading it
    intent = (f"intent://{base.split('://', 1)[1]}/r/{recipe.id}#Intent;scheme=https;"
              f"package={settings.ANDROID_PACKAGE};S.browser_fallback_url={quote(_apk_url(), safe='')};end")

    html = PAGE.format(
        lang=lang, title=escape(title), desc=escape(meta), image=escape(image), url=escape(url), base=escape(base),
        hero=f'<img class="hero" src="{escape(image)}" alt="">' if image else "",
        meta=escape(meta), intent=escape(intent), apk=escape(_apk_url()), ingredients=ingredients,
        t_open=escape(tx["open"]), t_get=escape(tx["get"]), t_hint=escape(tx["install_hint"]), t_teaser=escape(tx["teaser"]),
    )
    return HTMLResponse(html)
