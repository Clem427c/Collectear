"""Prépare les décors générés (art/decors/raw/, voir docs/prompts_decors.csv) pour le jeu.

  - tuiles (tile_*.png) : rendues raccordables (on peut les répéter sans couture visible) puis
    réduites en 512×512 → assets/images/decors/tile_*.png
  - éléments (prop_*, place_*, item_*, perso_*, ennemi_*) : fond blanc ET ombre pastel retirés
    (le jeu dessine sa propre ombre), recadrés au plus près, 256 px max → assets/images/decors/*.png
  - écrit assets/images/decors/manifest.json (liste des fichiers produits).

Usage : python3 tool/process_decors.py      Dépendances : pillow, numpy, scipy.
"""
import json
import re
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
# (Vide depuis le 28/10 : prairie et plateau sont maintenant ramenés à leur teinte par SOFT_GROUND.)
SATURATION: dict[str, float] = {}
MIRROR = {"tile_tour.png"}

# Lisibilité (retour de Clem du 28/10) : un sol d'herbe trop sombre ou trop chargé noie personnages et
# ennemis. S'il est plus sombre que ce seuil, on garde seulement son relief (très atténué) et on le
# recolore dans une teinte douce. Les sols régénérés avec les nouveaux prompts doux passent tels quels.
SOFT_GROUND = {
    "tile_l0_vallee.png": (150, 196, 120),   # vert sauge doux
    "tile_l1_prairie.png": (184, 214, 130),  # vert tendre, plus clair
    "tile_l2_plateau.png": (224, 208, 150),  # paille
}
DARK_LUMINANCE = 110  # luminance moyenne (0-255) en dessous de laquelle le sol est adouci
SOFT_RELIEF = 9       # amplitude du relief gardé, en niveaux de couleur


def grade_ground(img: Image.Image, target) -> Image.Image:
    """Ramène la couleur moyenne du sol sur la teinte de son étage, sans toucher au motif : les sols
    doux régénérés le 28/10 étaient tous crème très pâle, on ne distinguait plus les étages."""
    a = np.asarray(img).astype(float)
    a = a - a.reshape(-1, 3).mean(axis=0) + np.array(target, float)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def soften_ground(img: Image.Image, target) -> Image.Image:
    from PIL import ImageFilter
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(1.5))).astype(float)
    lum = a.mean(axis=2)
    relief = (lum - lum.mean()) / (lum.std() + 1e-6)
    out = np.array(target, float)[None, None, :] + relief[..., None] * SOFT_RELIEF
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def make_tile(f: Path) -> Image.Image:
    img = center_crop(Image.open(f).convert("RGB"))
    img = mirror_tile(img) if f.name in MIRROR else seamless(img)
    target = SOFT_GROUND.get(f.name)
    if target is not None:
        if np.asarray(img).mean() < DARK_LUMINANCE:
            print(f"  {f.name} : sol trop sombre, adouci (régénère-le avec le nouveau prompt doux)")
            img = soften_ground(img, target)
        else:
            img = grade_ground(img, target)
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


# Skins d'explorateur (lib/core/cosmetics.dart, seule source des couleurs) : la cape violette du
# personnage prend les couleurs du skin. Une image par pose et par skin : perso_explorateur_face__azur.png…
SKIN_RE = re.compile(r"Skin\(\s*(?:Skins\.)?(\w+|'[^']*'),\s*'[^']*',\s*(\d+),\s*0x([0-9A-Fa-f]{8}),\s*0x([0-9A-Fa-f]{8})")


def read_skins() -> list[tuple[str, tuple, tuple]]:
    """(id, couleur claire, couleur foncée) des skins payants, lus dans cosmetics.dart."""
    src = (ROOT / "lib/core/cosmetics.dart").read_text(encoding="utf-8")
    out = []
    for sid, price, light, dark in SKIN_RE.findall(src):
        if int(price) == 0 or not sid.startswith("'"):
            continue  # skin par défaut : image d'origine
        rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (2, 4, 6))
        out.append((sid.strip("'"), rgb(light), rgb(dark)))
    return out


def cape_mask(img: Image.Image) -> np.ndarray:
    """Pixels de la cape (violette sur les images de Clem) : teinte 245-340°, assez saturée."""
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(np.float32)
    h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1], hsv[..., 2]
    alpha = np.asarray(img.convert("RGBA"))[..., 3]
    return (h >= 245) & (h <= 340) & (s > 35) & (v > 25) & (alpha > 0)


def recolor_cape(img: Image.Image, light, dark) -> Image.Image:
    """Cape aux couleurs du skin : ombres → couleur foncée, lumières → couleur claire."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    m = cape_mask(img)
    if not m.any():
        return img
    lum = a[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    lo, hi = np.percentile(lum[m], 5), np.percentile(lum[m], 95)
    t = np.clip((lum - lo) / max(hi - lo, 1), 0, 1)[..., None]
    col = np.array(dark, np.float32) * (1 - t) + np.array(light, np.float32) * t
    a[..., :3] = np.where(m[..., None], col, a[..., :3])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    skins = read_skins()
    print(f"Skins : {', '.join(s[0] for s in skins) or 'aucun'}")
    for f in sorted(RAW.glob("*.png")) if RAW.exists() else []:
        if f.name.startswith("tile_"):
            img = Image.open(f)
            if img.width != img.height:
                continue  # falaise (non carrée) : pas utilisée pour l'instant
            make_tile(f).save(OUT / f.name, optimize=True)
        else:
            sprite = cutout(Image.open(f))
            sprite.save(OUT / f.name, optimize=True)
            if f.name.startswith("perso_explorateur"):
                for sid, light, dark in skins:
                    name = f.name.replace(".png", f"__{sid}.png")
                    recolor_cape(sprite, light, dark).save(OUT / name, optimize=True)
                    made.append(name)
        made.append(f.name)
    (OUT / "manifest.json").write_text(json.dumps(made), encoding="utf-8")
    print(f"{len(made)} décor(s) préparé(s) dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
