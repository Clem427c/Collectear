"""Captures d'écran téléphone pour la fiche Google Play (lancé par la CI après « flutter build web »).

Ouvre le jeu web dans Chromium en format téléphone 9:16 et enregistre des PNG en 1080×1920
(format accepté par Google Play pour les captures « Téléphone », 2 à 8 images) :
  1-jouer.png, 2-run.png, 3-bestiaire.png, 4-fiche.png, 5-boutique.png, 6-profil.png
Avant le chargement, une collection de démonstration est mise dans le stockage du navigateur
(comme si le joueur avait déjà fait quelques runs) pour que le bestiaire ne soit pas vide :
les exemplaires viennent de supabase/showcase.sql (seeds dont la variante est connue).

Usage : python3 tool/play_screenshots.py build/web build/play-screenshots
"""
import base64
import io
import json
import random
import re
import sys
import time
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

from web_smoke import BASE, serve

ROOT = Path(__file__).resolve().parent.parent
# 405×720 points × 8/3 = 1080×1920 pixels (9:16).
VIEW_W, VIEW_H, SCALE = 405, 720, 8 / 3
OUT_W, OUT_H = 1080, 1920


def demo_collection() -> list[str]:
    """Collection de démonstration au format de lib/core/collection.dart ("id:seed1,seed2")."""
    rarity = {c["id"]: c["rarity"] for c in json.loads((ROOT / "assets/data/cards.json").read_text("utf-8"))}
    seeds: dict[int, dict[str, int]] = {}
    for cid, seed, kind in re.findall(r"\((\d+), (\d+), '([a-z-]+)'\)", (ROOT / "supabase/showcase.sql").read_text("utf-8")):
        seeds.setdefault(int(cid), {})[kind] = int(seed)
    rng = random.Random(2026)
    # Part des espèces déjà trouvées selon la rareté (commune → légendaire).
    found = {0: 0.75, 1: 0.55, 2: 0.35, 3: 0.2, 4: 0.12}
    out = []
    for cid in sorted(seeds):
        if rng.random() >= found.get(rarity.get(cid, 0), 0.1):
            continue
        kinds = ["none", "stripes", "spots"]
        if rng.random() < 0.35:
            kinds.append(rng.choice(["rings", "stars", "shiny"]))
        if rng.random() < 0.08:
            kinds.append(rng.choice(["golden", "crystal", "shadow", "golden-shiny"]))
        picked = rng.sample(kinds[:3], rng.randint(1, 2)) + kinds[3:]
        out.append(f"{cid}:{','.join(str(seeds[cid][k]) for k in picked if k in seeds[cid])}")
    return out


def init_script() -> str:
    """Script exécuté avant le jeu : remplit le stockage de shared_preferences (préfixe « flutter. »)."""
    collection = demo_collection()
    rarity = {c["id"]: c["rarity"] for c in json.loads((ROOT / "assets/data/cards.json").read_text("utf-8"))}
    # Compagnon : la carte la plus rare de la collection de démonstration.
    companion = max((int(e.split(":")[0]) for e in collection), key=lambda i: (rarity.get(i, 0), i))
    prefs = {
        "flutter.owned_variants": json.dumps(collection),
        "flutter.coins": json.dumps(840),
        "flutter.pseudo": json.dumps("Aventurière"),
        "flutter.companion_id": json.dumps(companion),
        "flutter.stat_runs": json.dumps(23),
        "flutter.stat_kills": json.dumps(412),
        "flutter.stat_cards": json.dumps(61),
        "flutter.stat_best_kills": json.dumps(34),
        "flutter.stat_best_distance": json.dumps(286),
        "flutter.stat_places": json.dumps(19),
        "flutter.set_login_prompt_shown": json.dumps(True),
        "flutter.set_volume": json.dumps(0.0),
    }
    lines = [f"localStorage.setItem({json.dumps(k)}, {json.dumps(v)});" for k, v in prefs.items()]
    return "if (!sessionStorage.getItem('demo')) {" + "".join(lines) + "sessionStorage.setItem('demo','1');}"


def main():
    web_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    out_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "build/play-screenshots")
    out_dir.mkdir(parents=True, exist_ok=True)
    url = f"http://127.0.0.1:{serve(web_dir)}/{BASE}/"
    saved = []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader",
                                          "--autoplay-policy=no-user-gesture-required"])
        ctx = browser.new_context(viewport={"width": VIEW_W, "height": VIEW_H}, device_scale_factor=SCALE,
                                  is_mobile=False, has_touch=False)
        ctx.add_init_script(init_script())
        page = ctx.new_page()
        page.on("pageerror", lambda e: print("[pageerror]", str(e)[:500]))

        def save(name: str):
            img = Image.open(io.BytesIO(page.screenshot(type="png"))).convert("RGB")
            if img.size != (OUT_W, OUT_H):
                img = img.resize((OUT_W, OUT_H), Image.LANCZOS)
            img.save(out_dir / f"{name}.png", optimize=True)
            saved.append(name)
            # Vignette dans le journal de la CI (Claude ne peut pas télécharger les artefacts).
            thumb = io.BytesIO()
            img.resize((270, 480)).save(thumb, "JPEG", quality=55)
            print(f"CAPTURE-DEBUT play-{name}")
            print(base64.b64encode(thumb.getvalue()).decode())
            print("CAPTURE-FIN")

        def tap(text: str, timeout=3000, scroll=0) -> bool:
            for attempt in range(scroll + 1):
                for loc in (page.get_by_role("button", name=text), page.get_by_text(text, exact=False)):
                    try:
                        el = loc.first
                        el.wait_for(timeout=timeout)
                        box = el.bounding_box()
                        if box and 0 <= box["y"] + box["height"] / 2 <= VIEW_H:
                            page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
                        else:
                            el.click(timeout=timeout)
                        return True
                    except Exception:
                        pass
                if attempt < scroll:
                    page.mouse.move(VIEW_W / 2, VIEW_H / 2)
                    page.mouse.wheel(0, 500)
                    time.sleep(0.6)
            print(f"ATTENTION : « {text} » introuvable")
            return False

        def home():
            page.goto(url)
            page.wait_for_selector("flutter-view, flt-glass-pane", timeout=90_000)
            time.sleep(9)
            page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            time.sleep(1.5)
            tap("Plus tard", timeout=1500)  # au cas où la fenêtre de connexion s'ouvrirait quand même
            time.sleep(1)

        home()
        save("1-jouer")
        if tap("JOUER"):
            time.sleep(5)  # compte à rebours 3-2-1-GO
            page.mouse.click(VIEW_W / 2, VIEW_H / 3)
            for key, hold in (("ArrowRight", 1.6), ("ArrowUp", 0.8), ("ArrowRight", 1.0)):
                page.keyboard.down(key)
                time.sleep(hold)
                page.keyboard.up(key)
            page.keyboard.press("j")  # attaque
            time.sleep(0.25)
            save("2-run")
        home()
        if tap("Bestiaire"):
            time.sleep(2.5)
            save("3-bestiaire")
        home()
        if tap("Guide") and tap("Voir toutes les variantes", scroll=12):
            time.sleep(3)
            if tap("Dorée Shiny", scroll=2):
                time.sleep(3)
                save("4-fiche")
        home()
        if tap("Boutique"):
            time.sleep(2.5)
            save("5-boutique")
        if tap("Profil"):
            time.sleep(2.5)
            save("6-profil")
        browser.close()
    print(f"{len(saved)} capture(s) dans {out_dir}")
    # Google Play en demande au moins 2 : en dessous, quelque chose ne va pas.
    sys.exit(0 if len(saved) >= 2 else 1)


if __name__ == "__main__":
    main()
