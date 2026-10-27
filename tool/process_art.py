"""Prépare les illustrations des cartes pour le jeu.

Clem dépose les images générées (PNG ou JPG, nommées par numéro : 001.png, 042.jpg…)
dans art/raw/. Ce script :
  1. retire le fond blanc uni (remplissage depuis les bords, avec tolérance),
  2. retire aussi les « poches » de fond enfermées dans le dessin (entre les jambes et l'ombre
     au sol, entre un bras et une arme…) :
       - liste vérifiée à la main dans art/pockets.json (points de départ, par image) ;
       - pour une image absente de la liste (ou regénérée), règle automatique : poche blanche
         qui touche l'ombre au sol ;
  3. recadre et centre l'image de sorte que TOUT le dessin (ombre comprise) tienne dans le
     cercle inscrit du carré (le fond rond des cartes ne coupe plus rien),
  4. redimensionne en 512×512 et écrit assets/cards/NNN.png,
  5. met à jour assets/cards/manifest.json (liste des numéros illustrés).

Usage : python3 tool/process_art.py            (toutes les images)
        python3 tool/process_art.py 281 64     (seulement celles-ci)
        python3 tool/process_art.py --find-pockets 281   (liste les poches candidates, pour la revue)
Dépendances : pillow, numpy, scipy.
"""
import hashlib
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art/raw"
OUT = ROOT / "assets/cards"
POCKETS = ROOT / "art/pockets.json"
SIZE = 512
TOLERANCE = 14  # écart maximal au blanc pour être considéré comme fond (bas pour garder l'ombre au sol)
CIRCLE_MARGIN = 0.96  # le dessin occupe au plus 96 % du rayon du cercle inscrit


def sha1(path: Path) -> str:
    return hashlib.sha1(path.read_bytes()).hexdigest()[:12]


def near_white(rgb: np.ndarray) -> np.ndarray:
    return np.all(255 - rgb.astype(int) <= TOLERANCE, axis=2)


def border_background(near: np.ndarray) -> np.ndarray:
    """Fond relié aux bords de l'image."""
    lab, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(border))


def ground_shadow(rgb: np.ndarray, near: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Ombre au sol : grande zone claire et grise, collée au fond, dans le bas de l'image."""
    opaque = ~bg
    light = opaque & ~near & (rgb.min(axis=2) >= 150) & ((rgb.max(axis=2).astype(int) - rgb.min(axis=2)) <= 25)
    lab, _ = ndimage.label(light)
    touch = ndimage.binary_dilation(bg)
    h = rgb.shape[0]
    out = np.zeros_like(light)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None:
            continue
        m = lab[sl] == i
        if m.sum() > 2000 and (m & touch[sl]).sum() > 50 and (sl[0].start + sl[0].stop) / 2 > h * 0.6:
            out[sl] |= m
    return out


def pockets(rgb: np.ndarray, near: np.ndarray, bg: np.ndarray, min_size: int = 150):
    """Zones blanches enfermées dans le dessin : [(index, taille, pureté, contact ombre, point)]."""
    shadow = ground_shadow(rgb, near, bg)
    lab, _ = ndimage.label(near & ~bg)
    h, w = near.shape
    res = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None:
            continue
        y0, y1 = max(sl[0].start - 4, 0), min(sl[0].stop + 4, h)
        x0, x1 = max(sl[1].start - 4, 0), min(sl[1].stop + 4, w)
        m = lab[y0:y1, x0:x1] == i
        size = int(m.sum())
        if size < min_size:
            continue
        pure = float((rgb[y0:y1, x0:x1][m].min(axis=1) >= 253).mean())
        ring = ndimage.binary_dilation(m, iterations=3) & ~m
        touch = int((ring & shadow[y0:y1, x0:x1]).sum())
        ys, xs = np.nonzero(m)
        seed = (int(xs[len(xs) // 2]) + x0, int(ys[len(ys) // 2]) + y0)
        res.append((len(res), size, round(pure, 2), touch, seed))
    return res


def remove_background(path: Path, manual: dict) -> Image.Image:
    img = Image.open(path)
    if img.mode == "RGBA" and np.array(img)[..., 3].min() < 255:
        return img  # déjà transparent
    rgb = np.array(img.convert("RGB"))
    near = near_white(rgb)
    bg = border_background(near)
    lab, _ = ndimage.label(near & ~bg)
    key = path.stem.zfill(3)
    entry = manual.get(key)
    if entry and entry.get("sha1") == sha1(path):
        seeds = [tuple(s) for s in entry["seeds"]]
    else:
        # Image non revue : seules les poches pures qui touchent l'ombre au sol sont retirées.
        seeds = [p[4] for p in pockets(rgb, near, bg) if p[2] >= 0.5 and p[3] >= 20]
    for x, y in seeds:
        label = lab[y, x]
        if label:
            bg |= lab == label
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def square(img: Image.Image) -> Image.Image:
    """Centre le dessin dans un carré dont le cercle inscrit contient tous les pixels visibles."""
    bbox = img.getbbox() or (0, 0, img.width, img.height)
    img = img.crop(bbox)
    a = np.array(img)[..., 3] > 16
    ys, xs = np.nonzero(a)
    cx, cy = img.width / 2, img.height / 2
    if len(xs):
        radius = math.sqrt(float(((xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2).max()))
    else:
        radius = max(img.size) / 2
    side = int(math.ceil(2 * radius / CIRCLE_MARGIN))
    side = max(side, img.width, img.height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def raw_files(only):
    for f in sorted(RAW.glob("*")) if RAW.exists() else []:
        m = re.match(r"^(\d{1,3})\.(png|jpe?g|webp)$", f.name, re.I)
        if not m:
            print("ignoré (nom attendu : 001.png) :", f.name)
            continue
        n = int(m.group(1))
        if not 1 <= n <= 300:
            print("ignoré (numéro hors 1..300) :", f.name)
            continue
        if only and n not in only:
            continue
        yield n, f


def main(argv):
    if argv[:1] == ["--find-pockets"]:
        for n, f in raw_files({int(a) for a in argv[1:]}):
            rgb = np.array(Image.open(f).convert("RGB"))
            near = near_white(rgb)
            print(f"{n:03d} (sha1 {sha1(f)}) : index, taille, pureté, contact ombre, point")
            for p in pockets(rgb, near, border_background(near)):
                print("   ", p)
        return
    manual = json.loads(POCKETS.read_text(encoding="utf-8")) if POCKETS.exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)
    only = {int(a) for a in argv}
    done = []
    for n, f in raw_files(only):
        square(remove_background(f, manual)).save(OUT / f"{n:03d}.png", optimize=True)
        done.append(n)
    ids = sorted({int(p.stem) for p in OUT.glob("[0-9][0-9][0-9].png")})
    (OUT / "manifest.json").write_text(json.dumps(ids), encoding="utf-8")
    print(f"{len(done)} image(s) traitée(s) ; {len(ids)} carte(s) illustrée(s) au total")


if __name__ == "__main__":
    main(sys.argv[1:])
