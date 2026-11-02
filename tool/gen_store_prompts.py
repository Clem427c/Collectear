"""Écrit docs/prompts_store.csv : prompts FLUX de l'icône de l'appli et de l'image de présentation Google Play.

Même style que les cartes et les décors (cartoon coloré de jeu mobile, contours épais, cel shading),
et le même explorateur que le personnage jouable (cape violette, sacoche, épée courte).

  - icone.png        : 1024×1024, plein cadre (Google Play arrondit lui-même les coins ; Android en
                       garde surtout le centre), sujet centré avec de la marge. Plusieurs idées : la CI
                       prend art/store/raw/icone.png, à Clem de copier là sa préférée.
  - presentation.png : 1024×512 (FLUX veut des multiples de 16), recadrée en 1024×500 par la CI.
                       Sans texte : Google déconseille le texte dans l'image (le nom est affiché à côté).

Usage : python3 tool/gen_store_prompts.py   puis   python tool/comfy_batch.py --store
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/prompts_store.csv"

STYLE = ("cute colorful cartoon mobile game art, thick clean dark outlines, soft cel shading, "
         "vibrant saturated colors, simple readable shapes, original design, no text, no letters, no numbers, "
         "no watermark, no logo")

HERO = ("young adventurer explorer hero with small cute chibi proportions, big head, brown hair, short purple cape, "
        "brown leather satchel, short sword")

ICON = ("mobile game app icon, square composition, bold and instantly readable at a very small size, "
        "one single clear subject perfectly centered with a generous empty margin all around it, "
        "the subject fills only the central sixty percent of the image, "
        "smooth simple radial gradient background filling the whole square edge to edge, no border, no frame, "
        "no rounded corners, no scenery details, strong silhouette, high contrast, " + STYLE)

BANNER = ("wide horizontal promotional banner illustration for a top-down mobile adventure card collecting game, "
          "cinematic composition, main subject slightly left of center, lots of breathing room, "
          "important elements away from the edges, bright cheerful lighting, " + STYLE)

# (fichier, nom, largeur, hauteur, description) — la CI ne lit que icone.png et presentation.png ;
# les autres lignes sont des idées d'icône à renommer en icone.png si elles plaisent davantage.
ASSETS = [
    ("icone.png", "Icône : carte brillante", 1024, 1024,
     "a single glowing collectible trading card tilted slightly, golden ornate border, a cute round creature "
     "emblem on it, sparkles and a soft golden glow around the card, deep purple to violet gradient background"),
    ("icone_explorateur.png", "Icône (idée 2) : explorateur et carte", 1024, 1024,
     f"head and shoulders of a {HERO}, big happy eyes, holding up a glowing golden card next to his face, "
     "sparkles, warm teal to green gradient background"),
    ("icone_coffre.png", "Icône (idée 3) : coffre ouvert", 1024, 1024,
     "a small wooden treasure chest with golden trims, wide open, three glowing collectible cards bursting out "
     "of it in a fan shape with sparkles, deep blue to purple gradient background"),
    ("presentation.png", "Image de présentation Google Play", 1024, 512,
     f"a {HERO}, standing proudly on a grassy hilltop and holding up a glowing golden card, "
     "a fan of colorful collectible creature cards floating in the air around him, "
     "cute small forest creatures and a friendly little golem peeking nearby, "
     "a bright stylized landscape behind him with soft green hills on several height levels, "
     "a few round trees, a small stone tower on a far hill, clear blue sky with soft clouds"),
]


def main():
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["numero", "fichier", "nom", "sorte", "largeur", "hauteur", "prompt"])
        for i, (fichier, nom, lw, lh, desc) in enumerate(ASSETS, 1):
            sorte = "presentation" if lw != lh else "icone"
            base = BANNER if sorte == "presentation" else ICON
            w.writerow([i, fichier, nom, sorte, lw, lh, f"{desc}, {base}"])
    print(f"{len(ASSETS)} prompts écrits dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
