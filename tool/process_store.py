"""Icône de l'appli (Android + web) et images de la fiche Google Play, depuis art/store/raw/.

  - art/store/raw/icone.png (carré, voir docs/prompts_store.csv) → icônes Android (classiques et
    adaptatives), icônes web (PWA, favicon) et build/store/icone_512.png pour la Play Console.
    Tant qu'elle n'existe pas : icône PROVISOIRE dessinée ici (carte dorée sur fond violet), qui
    remplace au moins le logo Flutter par défaut.
  - art/store/raw/presentation.png (≈ 2:1) → build/store/presentation_1024x500.png (recadrée au centre).

Appelé par la CI après `flutter create` (dossiers android/ et web/). Ne touche qu'aux dossiers présents.
Usage : python3 tool/process_store.py [racine]      Dépendance : pillow.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
RAW = ROOT / "art/store/raw"
STORE = ROOT / "build/store"

# Icône classique (Android < 8 et lanceurs qui l'utilisent) : 48 dp ; calque adaptatif : 108 dp.
DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Généré par tool/process_store.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""


def placeholder_icon(size: int = 1024) -> Image.Image:
    """PROVISOIRE : carte dorée inclinée avec une étoile, sur un dégradé violet (dessin à 2× puis réduit)."""
    s = size * 2
    c = s / 2
    # Dégradé radial violet clair au centre → violet profond sur les bords.
    grad = Image.radial_gradient("L").resize((s, s))  # 0 au centre, 255 aux bords
    inner, outer = (150, 90, 230), (55, 20, 110)
    img = Image.merge("RGB", [grad.point(lambda v, a=a, b=b: int(a + (b - a) * min(v / 200, 1)))
                              for a, b in zip(inner, outer)])
    # Halo doré derrière la carte.
    halo = Image.new("L", (s, s), 0)
    ImageDraw.Draw(halo).ellipse((c - s * .33, c - s * .33, c + s * .33, c + s * .33), fill=150)
    halo = halo.filter(ImageFilter.GaussianBlur(s * .06))
    img = Image.composite(Image.new("RGB", (s, s), (255, 210, 90)), img, halo)
    # Carte : rectangle arrondi (bord doré, intérieur crème), inclinée de 10°.
    cw, ch = int(s * .36), int(s * .50)
    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    r = int(cw * .12)
    d.rounded_rectangle((0, 0, cw - 1, ch - 1), radius=r, fill=(240, 180, 40), outline=(60, 30, 10),
                        width=int(cw * .035))
    m = int(cw * .10)
    d.rounded_rectangle((m, m, cw - 1 - m, ch - 1 - m), radius=int(r * .6), fill=(255, 248, 225),
                        outline=(60, 30, 10), width=int(cw * .02))
    # Étoile à 5 branches au centre de la carte.
    cx, cy, ro, ri = cw / 2, ch / 2, cw * .27, cw * .11
    pts = [(cx + (ro if k % 2 == 0 else ri) * math.sin(k * math.pi / 5),
            cy - (ro if k % 2 == 0 else ri) * math.cos(k * math.pi / 5)) for k in range(10)]
    d.polygon(pts, fill=(250, 190, 30), outline=(60, 30, 10), width=int(cw * .025))
    card = card.rotate(10, resample=Image.BICUBIC, expand=True)
    # Ombre douce sous la carte.
    shadow = Image.new("RGBA", card.size, (20, 0, 50, 0))
    shadow.putalpha(card.getchannel("A").point(lambda a: a * 90 // 255).filter(ImageFilter.GaussianBlur(s * .015)))
    img = img.convert("RGBA")
    pos = (int(c - card.width / 2), int(c - card.height / 2))
    img.alpha_composite(shadow, (pos[0] + int(s * .015), pos[1] + int(s * .025)))
    img.alpha_composite(card, pos)
    return img.convert("RGB").resize((size, size), Image.LANCZOS)


def square(img: Image.Image) -> Image.Image:
    w, h = img.size
    k = min(w, h)
    return img.crop(((w - k) // 2, (h - k) // 2, (w - k) // 2 + k, (h - k) // 2 + k))


def rounded(img: Image.Image, radius: float = .22) -> Image.Image:
    """Coins arrondis (icône classique, PWA non « maskable »)."""
    s = img.width
    mask = Image.new("L", (s * 4, s * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s * 4 - 1, s * 4 - 1), radius=int(s * 4 * radius), fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask.resize((s, s), Image.LANCZOS))
    return out


def edge_color(img: Image.Image) -> str:
    """Couleur moyenne du bord : fond du calque adaptatif (presque jamais visible)."""
    a = img.convert("RGB").resize((64, 64))
    px = [a.getpixel((x, y)) for x in range(64) for y in (0, 63)] + \
         [a.getpixel((x, y)) for y in range(64) for x in (0, 63)]
    return "#%02X%02X%02X" % tuple(sum(p[i] for p in px) // len(px) for i in range(3))


def android_icons(icon: Image.Image, res: Path) -> list[str]:
    written = []
    for name, k in DENSITIES.items():
        d = res / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        rounded(icon.resize((round(48 * k * 4),) * 2, Image.LANCZOS)).resize((round(48 * k),) * 2, Image.LANCZOS) \
            .save(d / "ic_launcher.png")
        icon.resize((round(108 * k),) * 2, Image.LANCZOS).save(d / "ic_launcher_foreground.png")
        written += [f"{d.name}/ic_launcher.png", f"{d.name}/ic_launcher_foreground.png"]
    any_dpi = res / "mipmap-anydpi-v26"
    any_dpi.mkdir(parents=True, exist_ok=True)
    (any_dpi / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")
    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{edge_color(icon)}</color>\n</resources>\n', encoding="utf-8")
    return written + ["mipmap-anydpi-v26/ic_launcher.xml", "values/ic_launcher_background.xml"]


def web_icons(icon: Image.Image, web: Path) -> list[str]:
    (web / "icons").mkdir(parents=True, exist_ok=True)
    for n in (192, 512):
        rounded(icon.resize((n, n), Image.LANCZOS)).save(web / "icons" / f"Icon-{n}.png")
        icon.resize((n, n), Image.LANCZOS).save(web / "icons" / f"Icon-maskable-{n}.png")
    rounded(icon.resize((128, 128), Image.LANCZOS)).resize((32, 32), Image.LANCZOS).save(web / "favicon.png")
    return ["icons/Icon-192.png", "icons/Icon-512.png", "icons/Icon-maskable-*.png", "favicon.png"]


def main():
    STORE.mkdir(parents=True, exist_ok=True)
    src = RAW / "icone.png"
    if src.exists():
        icon = square(Image.open(src).convert("RGB")).resize((1024, 1024), Image.LANCZOS)
        print("Icône :", src.relative_to(ROOT))
    else:
        icon = placeholder_icon()
        print("Icône : PROVISOIRE (art/store/raw/icone.png absente, voir docs/prompts_store.csv)")
    icon.resize((512, 512), Image.LANCZOS).save(STORE / "icone_512.png")
    res = ROOT / "android/app/src/main/res"
    if res.is_dir():
        print("Android :", ", ".join(android_icons(icon, res)))
    web = ROOT / "web"
    if web.is_dir():
        print("Web :", ", ".join(web_icons(icon, web)))

    banner = RAW / "presentation.png"
    if banner.exists():
        img = Image.open(banner).convert("RGB")
        # Remplir 1024×500 (agrandir si besoin) puis recadrer au centre.
        k = max(1024 / img.width, 500 / img.height)
        img = img.resize((math.ceil(img.width * k), math.ceil(img.height * k)), Image.LANCZOS)
        x, y = (img.width - 1024) // 2, (img.height - 500) // 2
        img.crop((x, y, x + 1024, y + 500)).save(STORE / "presentation_1024x500.png")
        print("Image de présentation : build/store/presentation_1024x500.png")
    else:
        print("Image de présentation : absente (art/store/raw/presentation.png)")


if __name__ == "__main__":
    main()
