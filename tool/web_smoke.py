"""Test de fumée de la version web (lancé par la CI après « flutter build web »).

Sert build/web sous /Collectear/, ouvre le jeu dans Chromium sans écran (Playwright), passe la
fenêtre de connexion, lance une run, appuie sur les flèches, et affiche :
  - les messages de la console du navigateur (erreurs comprises) ;
  - des captures d'écran en JPEG base64 entre les balises CAPTURE-DEBUT / CAPTURE-FIN
    (pour que Claude, qui ne peut pas ouvrir le site, puisse les relire dans le journal de la CI).
Les boutons sont trouvés grâce à l'arbre d'accessibilité de Flutter (Semantics).

Usage : python3 tool/web_smoke.py build/web
"""
import base64
import functools
import http.server
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
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
    handler.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv.server_address[1]


def main():
    web_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    port = serve(web_dir)
    url = f"http://127.0.0.1:{port}/{BASE}/"
    logs = []
    problems = []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader",
                                          "--autoplay-policy=no-user-gesture-required"])
        page = browser.new_page(viewport={"width": 412, "height": 860})
        page.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        page.on("pageerror", lambda e: (logs.append(f"[pageerror] {e}"), problems.append(str(e))))

        def shot(name: str):
            data = page.screenshot(type="jpeg", quality=45)
            print(f"CAPTURE-DEBUT {name}")
            print(base64.b64encode(data).decode())
            print("CAPTURE-FIN")

        def tap(text: str, timeout=4000) -> bool:
            for loc in (page.get_by_role("button", name=text), page.get_by_text(text, exact=False)):
                try:
                    loc.first.click(timeout=timeout)
                    print(f"OK : touché « {text} »")
                    return True
                except Exception:
                    pass
            print(f"ATTENTION : « {text} » introuvable")
            return False

        page.goto(url)
        page.wait_for_selector("flutter-view, flt-glass-pane", timeout=90_000)
        time.sleep(10)
        # Active l'arbre d'accessibilité de Flutter (boutons cliquables par leur nom).
        page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
        time.sleep(2)
        shot("1-accueil")
        tap("Plus tard")
        time.sleep(1.5)
        shot("2-apres-connexion")
        tap("JOUER")
        time.sleep(3)
        shot("3-compte-a-rebours")
        time.sleep(3)
        page.keyboard.down("ArrowRight")
        time.sleep(1.2)
        page.keyboard.up("ArrowRight")
        page.keyboard.down("ArrowDown")
        time.sleep(0.8)
        page.keyboard.up("ArrowDown")
        time.sleep(0.5)
        shot("4-run-apres-deplacement")
        time.sleep(4)
        shot("5-run-plus-tard")
        browser.close()

    print("---- Console du navigateur ----")
    for line in logs[-200:]:
        print(line[:2000])
    print(f"---- {len(problems)} erreur(s) JavaScript ----")
    for e in problems:
        print("ERREUR :", e[:3000])


if __name__ == "__main__":
    main()
