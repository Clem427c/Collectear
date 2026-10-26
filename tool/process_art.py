"""Prépare les illustrations des cartes pour le jeu.

Clem dépose les images générées (PNG ou JPG, nommées par numéro : 001.png, 042.jpg…)
dans art/raw/. Ce script :
  1. retire le fond blanc uni (remplissage depuis les bords, avec tolérance),
  2. recadre au plus près du personnage et centre dans un carré,
  3. redimensionne en 512×512 et écrit assets/cards/NNN.png,
  4. met à jour assets/cards/manifest.json (liste des numéros illustrés).

Usage : python3 tool/process_art.py
"""
import json
import re
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art/raw"
OUT = ROOT / "assets/cards"
SIZE = 512
TOLERANCE = 38  # écart maximal au blanc pour être considéré comme fond


def remove_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    if any(px[x, y][3] < 255 for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]):
        return img  # déjà transparent
    def is_bg(p):
        return p[3] > 0 and all(255 - c <= TOLERANCE for c in p[:3])
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        p = px[x, y]
        if not is_bg(p):
            continue
        px[x, y] = (255, 255, 255, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return img


def square(img: Image.Image) -> Image.Image:
    bbox = img.getbbox() or (0, 0, img.width, img.height)
    img = img.crop(bbox)
    side = int(max(img.size) * 1.08)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    done = []
    for f in sorted(RAW.glob("*")) if RAW.exists() else []:
        m = re.match(r"^(\d{1,3})\.(png|jpe?g|webp)$", f.name, re.I)
        if not m:
            print("ignoré (nom attendu : 001.png) :", f.name)
            continue
        n = int(m.group(1))
        if not 1 <= n <= 300:
            print("ignoré (numéro hors 1..300) :", f.name)
            continue
        square(remove_background(Image.open(f))).save(OUT / f"{n:03d}.png", optimize=True)
        done.append(n)
    ids = sorted({int(p.stem) for p in OUT.glob("[0-9][0-9][0-9].png")})
    (OUT / "manifest.json").write_text(json.dumps(ids), encoding="utf-8")
    print(f"{len(done)} image(s) traitée(s) ; {len(ids)} carte(s) illustrée(s) au total")


if __name__ == "__main__":
    main()
