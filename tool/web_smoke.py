"""Test de fumée de la version web (lancé par la CI après « flutter build web »).

Sert build/web sous /Collectear/, ouvre le jeu dans Chromium sans écran (Playwright) en format
téléphone puis en format PC, passe la fenêtre de connexion, lance une run, appuie sur les flèches,
vérifie que l'image change, puis ouvre la galerie des variantes et la Boutique (skins). Il affiche :
  - les messages de la console du navigateur (erreurs comprises) ;
  - des captures d'écran en JPEG base64 entre les balises CAPTURE-DEBUT / CAPTURE-FIN
    (pour que Claude, qui ne peut pas ouvrir le site, puisse les relire dans le journal de la CI).
Les boutons sont trouvés grâce à l'arbre d'accessibilité de Flutter (Semantics).

Usage : python3 tool/web_smoke.py build/web
"""
import base64
import http.server
import io
import shutil
import sys
import tempfile
import threading
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = "Collectear"


def serve(web_dir: Path) -> int:
    root = Path(tempfile.mkdtemp())
    shutil.copytree(web_dir, root / BASE)

    class Quiet(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(root), **k)

        def log_message(self, *a):
            pass

    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Quiet)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv.server_address[1]


def changed_ratio(a: bytes, b: bytes) -> float:
    """Part des pixels qui ont changé entre deux captures (0 à 1)."""
    from PIL import Image, ImageChops
    ia = Image.open(io.BytesIO(a)).convert("L").resize((200, 200))
    ib = Image.open(io.BytesIO(b)).convert("L").resize((200, 200))
    diff = ImageChops.difference(ia, ib).point(lambda v: 255 if v > 24 else 0)
    return sum(1 for v in diff.getdata() if v) / (200 * 200)


def session(p, url: str, width: int, height: int, tag: str, problems: list, gallery: bool):
    logs = []
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader",
                                      "--autoplay-policy=no-user-gesture-required"])
    page = browser.new_page(viewport={"width": width, "height": height})
    page.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
    page.on("pageerror", lambda e: (logs.append(f"[pageerror] {e}"), problems.append(f"{tag} : {e}")))

    def grab() -> bytes:
        return page.screenshot(type="jpeg", quality=40)

    def shot(name: str, data: bytes | None = None):
        data = data or grab()
        print(f"CAPTURE-DEBUT {tag}-{name}")
        print(base64.b64encode(data).decode())
        print("CAPTURE-FIN")

    def tap(text: str, timeout=3000, scroll=0) -> bool:
        for attempt in range(scroll + 1):
            for loc in (page.get_by_role("button", name=text), page.get_by_text(text, exact=False)):
                try:
                    el = loc.first
                    el.wait_for(timeout=timeout)
                    box = el.bounding_box()
                    if box and 0 <= box["y"] + box["height"] / 2 <= height:
                        page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
                    else:
                        el.click(timeout=timeout)
                    print(f"OK ({tag}) : touché « {text} »")
                    return True
                except Exception:
                    pass
            if attempt < scroll:
                page.mouse.move(width / 2, height / 2)
                page.mouse.wheel(0, 500)
                time.sleep(0.6)
        print(f"ATTENTION ({tag}) : « {text} » introuvable")
        return False

    page.goto(url)
    page.wait_for_selector("flutter-view, flt-glass-pane", timeout=90_000)
    time.sleep(10)
    # Active l'arbre d'accessibilité de Flutter (boutons trouvables par leur nom).
    page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
    time.sleep(2)
    shot("1-accueil")
    tap("Plus tard")
    time.sleep(1.5)
    tap("JOUER")
    time.sleep(6)  # compte à rebours 3-2-1-GO
    before = grab()
    page.mouse.click(width / 2, height / 3)  # focus clavier sur le jeu (comme un joueur sur PC)
    for key, hold in (("ArrowRight", 1.5), ("ArrowDown", 1.0)):
        page.keyboard.down(key)
        time.sleep(hold)
        page.keyboard.up(key)
    after = grab()
    ratio = changed_ratio(before, after)
    print(f"MOUVEMENT ({tag}) : {ratio:.0%} de l'image a changé après les flèches")
    try:
        if page.get_by_text("Erreur technique", exact=False).count() > 0:
            problems.append(f"{tag} : bandeau « Erreur technique » affiché")
    except Exception:
        pass
    if ratio < 0.05:
        problems.append(f"{tag} : l'image ne change presque pas après les flèches ({ratio:.0%})")
    shot("2-run-avant", before)
    shot("3-run-apres-fleches", after)
    if gallery:
        page.goto(url)
        page.wait_for_selector("flutter-view, flt-glass-pane", timeout=90_000)
        time.sleep(8)
        page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
        time.sleep(1.5)
        tap("Guide")
        time.sleep(1.5)
        if tap("Voir toutes les variantes", scroll=12):
            time.sleep(3)
            shot("4-galerie")
            page.mouse.move(width / 2, height / 2)
            page.mouse.wheel(0, 600)
            time.sleep(1.5)
            shot("5-galerie-bas")
            if tap("Dorée Shiny", scroll=2):
                time.sleep(2.5)
                shot("6-fiche-doree-shiny")
        # Boutique : grille des skins (aperçus teintés).
        page.goto(url)
        page.wait_for_selector("flutter-view, flt-glass-pane", timeout=90_000)
        time.sleep(8)
        page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
        time.sleep(1.5)
        if tap("Boutique"):
            time.sleep(2)
            page.mouse.move(width / 2, height / 2)
            page.mouse.wheel(0, 350)
            time.sleep(1.5)
            shot("7-boutique-skins")
    browser.close()
    print(f"---- Console du navigateur ({tag}) ----")
    for line in logs[-80:]:
        print(line[:1500])


def main():
    web_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    url = f"http://127.0.0.1:{serve(web_dir)}/{BASE}/"
    problems = []
    with sync_playwright() as p:
        session(p, url, 412, 860, "tel", problems, gallery=True)
        session(p, url, 1600, 900, "pc", problems, gallery=False)
    print(f"---- {len(problems)} problème(s) ----")
    for e in problems:
        print("PROBLÈME :", e[:3000])
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
