"""Prépare les décors générés (art/decors/raw/, voir docs/prompts_decors.csv) pour le jeu.

  - tuiles (tile_*.png) : rendues raccordables (on peut les répéter sans couture visible) puis
    réduites en 512×512 → assets/images/decors/tile_*.png
  - éléments (prop_*, place_*, item_*, perso_*, ennemi_*) : fond blanc ET ombre pastel retirés
    (le jeu dessine sa propre ombre), recadrés au plus près, 256 px max → assets/images/decors/*.png
  - écrit assets/images/decors/manifest.json (liste des fichiers produits).

Usage : python3 tool/process_decors.py      Dépendances : pillow, numpy, scipy.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art/decors/raw"
OUT = ROOT / "assets/images/decors"
TILE_SIZE = 512
SPRITE_MAX = 256


def seamless(img: Image.Image) -> Image.Image:
    """Fond enchaîné : mélange l'image avec sa copie décalée d'une demi-largeur.
    Au centre on garde l'image d'origine, sur les bords la copie décalée (dont les bords se suivent)."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    shifted = np.roll(a, (h // 2, w // 2), axis=(0, 1))
    yy = np.abs(np.linspace(-1, 1, h))[:, None]
    xx = np.abs(np.linspace(-1, 1, w))[None, :]
    # Poids 1 au centre, 0 sur les bords, transition douce.
    weight = np.clip(1.0 - np.maximum(yy, xx), 0, 1) ** 0.6
    weight = np.clip(weight * 1.6, 0, 1)[..., None]
    out = a * weight + shifted * (1 - weight)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def center_crop(img: Image.Image, margin: float = 0.12) -> Image.Image:
    """Retire les bords (l'IA y met souvent un cadre ou un assombrissement)."""
    w, h = img.size
    return img.crop((int(w * margin), int(h * margin), int(w * (1 - margin)), int(h * (1 - margin))))


def mirror_tile(img: Image.Image) -> Image.Image:
    """Pour les motifs réguliers (dalles) : 2×2 en miroir, raccordable sans dédoublement des joints."""
    w, h = img.size
    out = Image.new("RGB", (w * 2, h * 2))
    out.paste(img, (0, 0))
    out.paste(img.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    out.paste(img.transpose(Image.FLIP_TOP_BOTTOM), (0, h))
    out.paste(img.transpose(Image.ROTATE_180), (w, h))
    return out


# Sols trop saturés : on adoucit un peu pour que personnages et objets ressortent.
SATURATION = {"tile_l1_prairie.png": 0.75, "tile_l2_plateau.png": 0.7}
MIRROR = {"tile_tour.png"}


def make_tile(f: Path) -> Image.Image:
    img = center_crop(Image.open(f).convert("RGB"))
    img = mirror_tile(img) if f.name in MIRROR else seamless(img)
    sat = SATURATION.get(f.name)
    if sat is not None:
        from PIL import ImageEnhance
        img = ImageEnhance.Color(img).enhance(sat)
    return img.resize((TILE_SIZE, TILE_SIZE), Image.LANCZOS)


def cutout(img: Image.Image) -> Image.Image:
    """Retire le fond blanc et l'ombre claire autour de l'objet (tout ce qui est clair et relié au bord)."""
    rgb = np.asarray(img.convert("RGB")).astype(int)
    # « Clair » : blanc, gris clair ou pastel (ombres colorées générées par l'IA).
    light = rgb.min(axis=2) >= 165
    lab, _ = ndimage.label(light)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # Petits trous blancs enfermés et très purs (entre les feuilles…) : fond aussi.
    near_white = np.all(rgb >= 246, axis=2) & ~bg
    lab2, n2 = ndimage.label(near_white)
    if n2:
        sizes = ndimage.sum(near_white, lab2, range(1, n2 + 1))
        for i, s in enumerate(sizes, 1):
            if s > 400:
                bg |= lab2 == i
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # Bord adouci d'un pixel.
    alpha = ndimage.uniform_filter(alpha.astype(np.float32), size=3).astype(np.uint8)
    alpha[bg & (ndimage.binary_erosion(bg, iterations=2))] = 0
    out = Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    out.thumbnail((SPRITE_MAX, SPRITE_MAX), Image.LANCZOS)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for f in sorted(RAW.glob("*.png")) if RAW.exists() else []:
        if f.name.startswith("tile_"):
            img = Image.open(f)
            if img.width != img.height:
                continue  # falaise (non carrée) : pas utilisée pour l'instant
            make_tile(f).save(OUT / f.name, optimize=True)
        else:
            cutout(Image.open(f)).save(OUT / f.name, optimize=True)
        made.append(f.name)
    (OUT / "manifest.json").write_text(json.dumps(made), encoding="utf-8")
    print(f"{len(made)} décor(s) préparé(s) dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
