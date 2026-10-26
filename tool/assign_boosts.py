"""Attribue un boost de compagnon fixe à chaque carte, d'après le sens de son nom.

Boosts : damage (dégâts), speed (vitesse), resistance (+1 vie), time (+30 s), range (portée d'attaque).
Usage : python3 tool/assign_boosts.py  → met à jour assets/data/cards.json
"""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CARDS = ROOT / "assets/data/cards.json"

# Racines des noms de créatures → boost (avec la logique en commentaire).
STEMS = {
    # Vitesse : animaux rapides, vent, éclair, insectes volants
    "Vent": "speed", "Libell": "speed", "Lynx": "speed", "Guêp": "speed", "Frel": "speed",
    "Mouett": "speed", "Cerv": "speed", "Geck": "speed", "Léz": "speed", "Belett": "speed",
    "Corb": "speed", "Papill": "speed", "Écum": "speed", "Torr": "speed", "Dun": "speed",
    "Loutr": "speed", "Abeill": "speed", "Més": "speed", "Pins": "speed", "Lièvr": "speed",
    # Résistance : carapaces, pierres, cristaux, piquants, gros animaux
    "Roch": "resistance", "Quartz": "resistance", "Silex": "resistance", "Coquill": "resistance",
    "Écaill": "resistance", "Crabb": "resistance", "Hériss": "resistance", "Escarg": "resistance",
    "Ours": "resistance", "Sangl": "resistance", "Galet": "resistance", "Jasp": "resistance",
    "Saph": "resistance", "Opal": "resistance", "Nacr": "resistance", "Cristall": "resistance",
    "Glac": "resistance", "Gland": "resistance", "Nois": "resistance", "Mul": "resistance",
    "Taup": "resistance", "Blair": "resistance", "Tourb": "resistance", "Rouill": "resistance",
    # Dégâts : crocs, griffes, feu, foudre, épines, dards
    "Croc": "damage", "Griff": "damage", "Fang": "damage", "Flamm": "damage", "Brais": "damage",
    "Cendr": "damage", "Tonn": "damage", "Épin": "damage", "Ronc": "damage", "Charb": "damage",
    "Souffr": "damage", "Grel": "damage", "Pieuvr": "damage", "Salam": "damage", "Crap": "damage",
    "Fourm": "damage", "Rasc": "damage", "Gob": "damage", "Ambr": "damage", "Trit": "damage",
    # Temps : lune, soleil, sable (sablier), brume, végétaux lents, eau calme
    "Lun": "time", "Sol": "time", "Sabl": "time", "Brum": "time", "Mouss": "time", "Lierr": "time",
    "Myrt": "time", "Lich": "time", "Bulb": "time", "Pétal": "time", "Pomm": "time", "Plum": "time",
    "Givr": "time", "Saul": "time", "Trembl": "time", "Marr": "time", "Ombr": "time",
    "Grenouill": "time", "Têt": "time", "Hib": "time", "Cigal": "time",
}

# Portée (prioritaire) : langues, tentacules, lianes et ronces qui attrapent de loin.
RANGE_STEMS = ["Grenouill", "Crap", "Pieuvr", "Lierr", "Ronc", "Trit", "Salam", "Libell", "Mouett"]
RANGE_ROLES = ["Archère", "Chasseu", "Pêcheu", "Arcaniste", "Mage des Cendres", "Chevauch", "Dernier Mage"]

# Rôles des héros → boost.
ROLES = {
    "speed": ["Vagabond", "Éclaireu", "Pisteu", "Rôdeu", "Chevauch", "Corsaire", "Archère", "Voleur"],
    "resistance": ["Garde", "Gardien", "Forgeron", "Paladin", "Moine", "Moniale", "Chevalier", "Cœur-de-Fer",
                   "Immortelle"],
    "damage": ["Bûcheron", "Mercenaire", "Duelliste", "Maître-Lame", "Maîtresse-Lame", "Chasseu",
               "Briseur", "Lame d'Aube", "Brise-Étoiles"],
    "time": ["Berger", "Bergère", "Cueilleu", "Pêcheu", "Marchand", "Apprenti", "Alchimiste", "Barde",
             "Druide", "Arcaniste", "Mage", "Prêtresse", "Tisseuse", "Dompteuse", "Seuils"],
}

# Épiques et légendaires nommés à la main.
MANUAL = {
    "Astrelune": "time", "Volcarion": "damage", "Abyssiel": "resistance", "Tempestor": "speed",
    "Sylvarche": "resistance", "Glacivore": "damage", "Chronoptère": "time", "Néantor": "damage",
    "Pyralis": "damage", "Hydromance": "range", "Fulgurion": "speed", "Basaltor": "resistance",
    "Noctifère": "speed", "Cristalame": "damage", "Orageon": "speed", "Mirelune": "time",
    "Sabrecorne": "damage", "Ronceroi": "resistance", "Cendrolithe": "resistance", "Aquilarc": "range",
    "Vortexis": "speed", "Sépulcrin": "time", "Émeraudon": "resistance", "Marévore": "damage",
    "Solsticien": "time", "Givrespectre": "time",
}


def boost_for(card):
    name = card["name"]
    if name in MANUAL:
        return MANUAL[name]
    if card["family"] == "hero":
        if any(k in name for k in RANGE_ROLES):
            return "range"
        for boost, keys in ROLES.items():
            if any(k in name for k in keys):
                return boost
        raise SystemExit(f"Rôle de héros inconnu : {name}")
    if any(name.startswith(k) for k in RANGE_STEMS):
        return "range"
    for stem in sorted(STEMS, key=len, reverse=True):
        if name.startswith(stem):
            return STEMS[stem]
    raise SystemExit(f"Racine inconnue : {name}")


def main():
    cards = json.loads(CARDS.read_text(encoding="utf-8"))
    for c in cards:
        c["boost"] = boost_for(c)
    CARDS.write_text(json.dumps(cards, ensure_ascii=False, indent=1), encoding="utf-8")
    print("Total :", Counter(c["boost"] for c in cards))
    for r in range(5):
        print("Rareté", r, Counter(c["boost"] for c in cards if c["rarity"] == r))


if __name__ == "__main__":
    main()
