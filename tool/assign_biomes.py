"""Attribue un biome d'origine à chaque carte, d'après le sens de son nom (GDD diapo 11 : « chaque biome a ses espèces »).

PROVISOIRE (question à Clem) : 3 biomes du jeu (lib/core/biomes.dart).
- prairie   : champs, fleurs, eau calme, insectes et oiseaux, métiers des villages (berger, pêcheur, marchand…)
- foret     : arbres, champignons, bêtes des bois, métiers des bois (bûcheron, cueilleur, druide, rôdeur…)
- rocailles : pierres, cristaux, glace, feu, sable, orage, métiers de la pierre et de la magie (forgeron, mage…)
Usage : python3 tool/assign_biomes.py  → ajoute le champ "biome" dans assets/data/cards.json
"""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CARDS = ROOT / "assets/data/cards.json"

STEMS = {
    "rocailles": [
        "Cristall", "Galet", "Glac", "Roch", "Écaill", "Cendr", "Ambr", "Rouill", "Quartz", "Souffr", "Silex",
        "Sabl", "Grel", "Saph", "Flamm", "Opal", "Charb", "Brais", "Dun", "Jasp", "Givr", "Lich",
        "Mul", "Léz", "Geck", "Salam", "Tonn", "Nacr",
    ],
    "foret": [
        "Ombr", "Escarg", "Blair", "Belett", "Nois", "Hib", "Lierr", "Myrt", "Gob", "Ours", "Ronc", "Griff",
        "Hériss", "Gland", "Fourm", "Mouss", "Lynx", "Cerv", "Corb", "Sangl", "Croc", "Fang", "Épin", "Marr",
        "Trembl", "Tourb", "Taup", "Lun",
    ],
    "prairie": [
        "Loutr", "Trit", "Mouett", "Plum", "Més", "Bulb", "Cigal", "Grenouill", "Brum", "Saul", "Vent",
        "Libell", "Frel", "Abeill", "Papill", "Pieuvr", "Torr", "Rasc", "Guêp", "Pins", "Écum", "Pomm",
        "Pétal", "Têt", "Crap", "Coquill", "Crabb", "Lièvr",
    ],
}

# Rôles des héros → biome (le premier trouvé gagne, du plus précis au plus général).
ROLES = [
    ("rocailles", ["Gardienne des Ruines", "Chevaucheur de Wyverne", "Briseur de Rocs", "Tisseuse d'Orage",
                   "Mage des Cendres", "Dernier Mage", "Brise-Étoiles", "Cœur-de-Fer", "Immortelle", "Seuils",
                   "Forgeron", "Alchimiste", "Arcaniste", "Moine", "Moniale"]),
    ("prairie", ["Prêtresse des Marées", "Voleur de Lunes", "Pêcheu", "Berg", "Marchand", "Barde", "Vagabond",
                 "Apprenti", "Corsaire", "Chevalier", "Paladin", "Garde", "Duelliste", "Maître-Lame", "Lame d'Aube"]),
    ("foret", ["Chasseu", "Archère", "Dompteuse", "Bûcheron", "Cueilleu", "Rôdeu", "Pisteu", "Druide",
               "Éclaireu", "Mercenaire"]),
]

# Épiques et légendaires nommés à la main.
MANUAL = {
    "Basaltor": "rocailles", "Givrespectre": "rocailles", "Hydromance": "prairie", "Solsticien": "prairie",
    "Vortexis": "prairie", "Pyralis": "rocailles", "Orageon": "rocailles", "Mirelune": "prairie",
    "Cendrolithe": "rocailles", "Aquilarc": "prairie", "Marévore": "prairie", "Cristalame": "rocailles",
    "Fulgurion": "rocailles", "Sépulcrin": "foret", "Émeraudon": "foret", "Sabrecorne": "foret",
    "Noctifère": "foret", "Ronceroi": "foret", "Glacivore": "rocailles", "Sylvarche": "foret",
    "Abyssiel": "prairie", "Néantor": "foret", "Chronoptère": "rocailles", "Volcarion": "rocailles",
    "Tempestor": "prairie", "Astrelune": "foret",
    "Aurèle l'Immortelle": "prairie", "Ysolde Brise-Étoiles": "prairie", "Kaelith, Gardien des Seuils": "foret",
}


def biome_for(card):
    name = card["name"]
    if name in MANUAL:
        return MANUAL[name]
    if card["family"] == "hero":
        for biome, keys in ROLES:
            if any(k in name for k in keys):
                return biome
        raise SystemExit(f"Rôle de héros inconnu : {name}")
    matches = [(len(s), b) for b, stems in STEMS.items() for s in stems if name.startswith(s)]
    if not matches:
        raise SystemExit(f"Racine inconnue : {name}")
    return max(matches)[1]


def main():
    cards = json.loads(CARDS.read_text(encoding="utf-8"))
    for c in cards:
        c["biome"] = biome_for(c)
    CARDS.write_text(json.dumps(cards, ensure_ascii=False, indent=1), encoding="utf-8")
    print("Total :", Counter(c["biome"] for c in cards))
    for r in range(5):
        print("Rareté", r, Counter(c["biome"] for c in cards if c["rarity"] == r))
    for f in ("creature", "hero"):
        print(f, Counter(c["biome"] for c in cards if c["family"] == f))


if __name__ == "__main__":
    main()
