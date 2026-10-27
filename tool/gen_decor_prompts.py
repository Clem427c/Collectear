"""Écrit docs/prompts_decors.csv : prompts FLUX pour les décors, le personnage jouable et les ennemis.

Même style que les cartes (cartoon coloré de jeu mobile, contours épais, cel shading) pour que
le monde et la collection aillent ensemble. Vue de jeu : dessus avec une légère perspective (3/4).

Trois sortes d'images :
  - tuile   : texture de sol vue de dessus, qui doit pouvoir se répéter (pas de fond blanc) ;
  - objet   : élément posé dans le monde (arbre, rocher, coffre…), sur fond blanc pur à détourer ;
  - perso   : personnage jouable et ennemis, sur fond blanc pur à détourer.

Usage : python3 tool/gen_decor_prompts.py   puis   python tool/comfy_batch.py --decors
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/prompts_decors.csv"

STYLE = ("cute colorful cartoon mobile game art, thick clean dark outlines, soft cel shading, "
         "vibrant saturated colors, simple readable shapes, original design, no text, no letters, no watermark")

TILE = ("seamless tileable texture, perfectly top-down orthographic view looking straight down, "
        "evenly lit, no shadows from objects, no horizon, no perspective, the pattern fills the whole image edge to edge, "
        "no characters, no objects, no border, game terrain tile, " + STYLE)

PROP = ("single game prop seen from above at a three-quarter top-down angle, like a top-down mobile adventure game, "
        "centered, the whole object fully inside the image with a white margin, soft round shadow on the ground under it, "
        "isolated on a plain pure white background, no scenery, no ground texture, no other objects, " + STYLE)

CHAR = ("single game character sprite seen from a three-quarter top-down angle, like a top-down mobile action adventure game, "
        "full body, centered, the whole character fully inside the image with a white margin, "
        "soft round shadow on the ground under the character, isolated on a plain pure white background, "
        "no scenery, no floating objects, " + STYLE)

# (fichier, nom, sorte, largeur, hauteur, description)
ASSETS = [
    # --- Sol : un niveau de hauteur = un sol (du plus bas au plus haut) ---
    ("tile_l0_vallee.png", "Sol niveau 0 : vallée", "tuile", 1024, 1024,
     "lush dark green grass of a shaded valley, short dense grass blades, a few tiny clover leaves, deep green tones"),
    ("tile_l1_prairie.png", "Sol niveau 1 : prairie", "tuile", 1024, 1024,
     "bright green meadow grass, soft grass tufts, a few tiny white and yellow flowers scattered sparsely"),
    ("tile_l2_plateau.png", "Sol niveau 2 : plateau", "tuile", 1024, 1024,
     "light yellow-green plateau grass, short dry grass with small pebbles, sunny warm tones"),
    ("tile_l3_roche.png", "Sol niveau 3 : roche", "tuile", 1024, 1024,
     "sandy beige rocky ground, flat cracked stone slabs with small gravel, warm sandstone colors"),
    ("tile_l4_sommet.png", "Sol niveau 4 : sommet enneigé", "tuile", 1024, 1024,
     "fresh white snow on a mountain top, soft snow with subtle light blue shading and small ice sparkles"),
    ("tile_tour.png", "Sol des tours", "tuile", 1024, 1024,
     "ancient carved stone floor tiles, square lilac grey flagstones with mossy joints, magical temple floor"),
    ("tile_falaise.png", "Falaise (bord des étages)", "tuile", 1024, 512,
     "front view of a cartoon cliff face, layered dark brown and purple rock strata, side view of a ledge, "
     "repeating horizontally, grass fringe along the top edge"),
    ("tile_eau.png", "Eau (pour plus tard)", "tuile", 1024, 1024,
     "clear turquoise water seen from above, gentle cartoon ripples and small white sparkles"),

    # --- Végétation et rochers ---
    ("prop_arbre_rond.png", "Arbre rond", "objet", 1024, 1024,
     "round leafy cartoon tree with a thick brown trunk and a fluffy bright green crown"),
    ("prop_arbre_pin.png", "Sapin", "objet", 1024, 1024, "tall cartoon pine tree with layered dark green branches"),
    ("prop_arbre_enneige.png", "Sapin enneigé", "objet", 1024, 1024,
     "cartoon pine tree covered with snow, white snow caps on dark green branches"),
    ("prop_arbre_fruits.png", "Arbre à fruits", "objet", 1024, 1024,
     "small cartoon apple tree with a round green crown and shiny red fruits"),
    ("prop_buisson.png", "Buisson", "objet", 1024, 1024, "round cartoon green bush with a few pink berries"),
    ("prop_fleurs.png", "Touffe de fleurs", "objet", 1024, 1024,
     "small cluster of colorful cartoon wild flowers, pink yellow and purple petals, green leaves"),
    ("prop_champignons.png", "Champignons", "objet", 1024, 1024,
     "small group of three cartoon mushrooms with red caps and white dots"),
    ("prop_herbes_hautes.png", "Herbes hautes", "objet", 1024, 1024, "tuft of tall cartoon grass with soft green blades"),
    ("prop_rocher.png", "Rocher", "objet", 1024, 1024, "rounded grey cartoon boulder with a bit of moss on top"),
    ("prop_rochers_petits.png", "Petits rochers", "objet", 1024, 1024, "group of three small rounded grey cartoon stones"),
    ("prop_cristaux.png", "Cristaux", "objet", 1024, 1024,
     "cluster of glowing magical blue and purple crystals growing from a small rock"),
    ("prop_souche.png", "Souche", "objet", 1024, 1024, "cartoon tree stump with visible rings and a small mushroom"),

    # --- Lieux à découvrir (voir lib/core/places.dart) ---
    ("place_coffre.png", "Coffre", "objet", 1024, 1024,
     "closed wooden treasure chest with golden metal corners and a golden lock, slight golden glow"),
    ("place_coffre_ouvert.png", "Coffre ouvert", "objet", 1024, 1024,
     "open wooden treasure chest with golden corners, bright golden light shining out of it"),
    ("place_coffre_rare.png", "Coffre rare", "objet", 1024, 1024,
     "closed ornate purple and silver magical treasure chest with glowing violet gems, mystical violet aura"),
    ("place_sanctuaire.png", "Sanctuaire (éteint)", "objet", 1024, 1024,
     "ancient stone altar on a round stone platform, with an unlit dark grey crystal orb on top, carved runes, dormant"),
    ("place_sanctuaire_eveille.png", "Sanctuaire (éveillé)", "objet", 1024, 1024,
     "ancient stone altar on a round stone platform, with a brightly glowing golden orb on top, golden magical light rays"),
    ("place_ruine.png", "Ruine (portail fermé)", "objet", 1024, 1024,
     "ancient ruined stone archway portal, cracked mossy pillars, the opening is dark and empty, three unlit rune sockets"),
    ("place_ruine_ouverte.png", "Ruine (portail ouvert)", "objet", 1024, 1024,
     "ancient ruined stone archway portal, cracked mossy pillars, the opening filled with swirling glowing cyan magic light"),
    ("place_rune.png", "Pierre runique (éteinte)", "objet", 1024, 1024,
     "flat round stone slab on the ground with a carved triangle rune, unlit, grey"),
    ("place_rune_active.png", "Pierre runique (activée)", "objet", 1024, 1024,
     "flat round stone slab on the ground with a carved triangle rune glowing bright cyan, magical sparkles"),
    ("place_sommet_tour.png", "Sommet de tour", "objet", 1024, 1024,
     "small stone pedestal with a golden banner flag, top of an ancient tower, celebratory"),

    # --- Pièces ---
    ("item_piece.png", "Pièce", "objet", 1024, 1024,
     "single shiny gold coin with a small star engraved in the middle, seen slightly from above"),
    ("item_tas_pieces.png", "Tas de pièces", "objet", 1024, 1024, "small pile of shiny gold coins with a few sparkles"),

    # --- Personnage jouable ---
    ("perso_explorateur_face.png", "Explorateur (face)", "perso", 1024, 1024,
     "young adventurer explorer hero, small and cute chibi proportions, big head, brown hair, short purple cape, "
     "brown leather satchel, holding a short sword, friendly determined expression, facing the viewer, idle standing pose"),
    ("perso_explorateur_dos.png", "Explorateur (dos)", "perso", 1024, 1024,
     "young adventurer explorer hero, small and cute chibi proportions, big head, brown hair, short purple cape, "
     "brown leather satchel, holding a short sword, seen from behind walking away, back view"),
    ("perso_explorateur_profil.png", "Explorateur (profil)", "perso", 1024, 1024,
     "young adventurer explorer hero, small and cute chibi proportions, big head, brown hair, short purple cape, "
     "brown leather satchel, holding a short sword, side view facing right, running pose"),
    ("perso_explorateur_attaque.png", "Explorateur (attaque)", "perso", 1024, 1024,
     "young adventurer explorer hero, small and cute chibi proportions, big head, brown hair, short purple cape, "
     "swinging a short sword in a wide arc with a white slash effect, facing right, action pose"),

    # --- Ennemis (voir lib/game/enemy.dart : corps à corps et à distance) ---
    ("ennemi_cac.png", "Ennemi corps à corps", "perso", 1024, 1024,
     "small mischievous goblin-like forest creature monster, red skin, angry eyes, holding a wooden club, "
     "chibi proportions, menacing but cute, facing the viewer, ready to charge"),
    ("ennemi_cac_elite.png", "Ennemi corps à corps (gardien)", "perso", 1024, 1024,
     "bulky stone golem guardian monster, dark grey rock body with glowing orange cracks, big fists, "
     "chibi proportions, intimidating, facing the viewer"),
    ("ennemi_distance.png", "Ennemi à distance", "perso", 1024, 1024,
     "small hooded imp creature monster, orange skin, holding a slingshot, sly grin, "
     "chibi proportions, menacing but cute, facing the viewer"),
    ("ennemi_distance_elite.png", "Ennemi à distance (gardien)", "perso", 1024, 1024,
     "small floating dark mage spirit monster in a tattered purple robe, glowing yellow eyes, casting a magic orb, "
     "chibi proportions, intimidating, facing the viewer"),
    ("ennemi_projectile.png", "Projectile ennemi", "objet", 1024, 1024,
     "small glowing orange magic fireball projectile with a short trail"),
]


def main():
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["numero", "fichier", "nom", "sorte", "largeur", "hauteur", "prompt"])
        for i, (fichier, nom, sorte, lw, lh, desc) in enumerate(ASSETS, 1):
            base = {"tuile": TILE, "objet": PROP, "perso": CHAR}[sorte]
            w.writerow([i, fichier, nom, sorte, lw, lh, f"{desc}, {base}"])
    print(f"{len(ASSETS)} prompts écrits dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
