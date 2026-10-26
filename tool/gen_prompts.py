"""Génère les prompts d'illustration des 300 cartes (style cartoon coloré et rond).

Usage : python3 tool/gen_prompts.py → docs/prompts_illustrations.csv
Les prompts sont en anglais (les générateurs d'images les comprennent mieux).
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CARDS = json.loads((ROOT / "assets/data/cards.json").read_text(encoding="utf-8"))

STYLE = (
    "cute colorful cartoon mobile game character, round chunky shapes, thick clean dark outlines, "
    "soft cel shading, vibrant saturated colors, big expressive eyes, simple readable silhouette, "
    "full body, centered, 3/4 front view, plain white background, original design"
)
NEGATIVE = (
    "text, letters, watermark, logo, signature, card frame, border, realistic, photo, 3d render, "
    "gore, scary, multiple characters, cropped, resembling Pokemon or any existing franchise character"
)

# Racines des créatures → (type, description en anglais)
ANIMALS = {
    "Grenouill": "frog", "Têt": "tadpole", "Hib": "owl", "Corb": "crow", "Loutr": "otter", "Blair": "badger",
    "Hériss": "hedgehog", "Taup": "mole", "Mul": "mule", "Belett": "weasel", "Cerv": "deer fawn", "Lynx": "lynx",
    "Ours": "bear cub", "Sangl": "wild boar", "Salam": "salamander", "Trit": "newt", "Crap": "toad",
    "Escarg": "snail", "Libell": "dragonfly", "Papill": "butterfly", "Abeill": "bee", "Més": "titmouse bird",
    "Pins": "finch bird", "Cigal": "cicada", "Geck": "gecko", "Fourm": "ant", "Crabb": "crab",
    "Mouett": "seagull", "Pieuvr": "octopus", "Rasc": "scorpionfish", "Gob": "goby fish", "Guêp": "wasp",
    "Frel": "hornet", "Léz": "lizard", "Croc": "fanged critter", "Griff": "clawed critter",
}
ELEMENTS = {
    "Brais": "glowing embers", "Givr": "frost", "Mouss": "soft green moss", "Brum": "drifting mist",
    "Écum": "sea foam", "Sabl": "golden sand", "Cendr": "grey ash and sparks", "Grel": "hailstones",
    "Silex": "flint stone", "Saul": "willow leaves", "Nacr": "pearly mother-of-pearl", "Ambr": "amber resin",
    "Ombr": "shadows", "Tonn": "thunder clouds and sparks", "Flamm": "flames", "Glac": "ice crystals",
    "Roch": "rock", "Pétal": "flower petals", "Plum": "fluffy feathers", "Écaill": "shiny scales",
    "Lun": "moonlight", "Vent": "swirling wind", "Coquill": "seashells", "Épin": "thorns", "Torr": "rushing water",
    "Lich": "lichen", "Gland": "acorns", "Fang": "mud", "Bulb": "flower bulbs", "Cristall": "crystals",
    "Rouill": "rusty metal", "Pomm": "apples", "Tourb": "peat and bog plants", "Ronc": "brambles",
    "Lierr": "ivy vines", "Chard": "thistles", "Myrt": "blueberries", "Charb": "coal", "Souffr": "sulfur",
    "Quartz": "quartz", "Opal": "opal", "Jasp": "jasper stone", "Saph": "sapphire", "Galet": "smooth pebbles",
    "Dun": "sand dunes", "Marr": "chestnuts", "Nois": "hazelnuts", "Trembl": "trembling aspen leaves",
}
STAGE = {
    0: "tiny baby-like creature, very cute and chubby",
    1: "young playful creature, a little bigger and bolder",
    2: "evolved confident creature with distinctive features",
}

ROLE_EN = {
    "Vagabond": "wandering traveler with a bindle", "Vagabonde": "wandering traveler with a bindle",
    "Apprenti": "young apprentice with a book", "Apprentie": "young apprentice with a book",
    "Pêcheur": "fisher with a fishing rod", "Pêcheuse": "fisher with a fishing rod",
    "Bûcheron": "lumberjack with an axe", "Bûcheronne": "lumberjack with an axe",
    "Garde": "town guard with a spear and shield", "Éclaireur": "scout with a spyglass",
    "Éclaireuse": "scout with a spyglass", "Forgeron": "blacksmith with a hammer",
    "Forgeronne": "blacksmith with a hammer", "Berger": "shepherd with a crook", "Bergère": "shepherd with a crook",
    "Cueilleur": "forager with a basket of herbs", "Cueilleuse": "forager with a basket of herbs",
    "Marchand": "traveling merchant with a backpack", "Marchande": "traveling merchant with a backpack",
    "Rôdeur": "hooded ranger", "Rôdeuse": "hooded ranger", "Mercenaire": "mercenary with a sword",
    "Alchimiste": "alchemist with bubbling potions", "Duelliste": "duelist with a rapier",
    "Pisteur": "tracker with a bow", "Pisteuse": "tracker with a bow", "Moine": "martial arts monk",
    "Moniale": "martial arts monk", "Corsaire": "swashbuckling pirate", "Barde": "bard with a lute",
    "Paladin": "paladin in shining armor", "Paladine": "paladin in shining armor",
    "Mage des Cendres": "ash mage with smoky magic", "Maître-Lame": "blade master with two swords",
    "Maîtresse-Lame": "blade master with two swords", "Druide": "druid with a leafy staff",
    "Druidesse": "druid with a leafy staff", "Arcaniste": "arcanist with floating runes",
    "Gardien des Ruines": "ancient ruins guardian with a stone shield",
    "Gardienne des Ruines": "ancient ruins guardian with a stone shield",
    "Chasseur de Primes": "bounty hunter with a crossbow", "Chasseuse de Primes": "bounty hunter with a crossbow",
    "Chevaucheur de Wyverne": "wyvern rider with a lance", "Chevaucheuse de Wyverne": "wyvern rider with a lance",
}
HERO_STAGE = {0: "humble everyday adventurer", 1: "seasoned adventurer", 2: "renowned hero"}

MANUAL = {
    # Légendaires
    "Astrelune": "majestic celestial fox-like creature made of starlight and a crescent moon",
    "Volcarion": "majestic volcanic dragon-lion with lava mane",
    "Abyssiel": "majestic deep-sea serpent with glowing bioluminescent patterns",
    "Tempestor": "majestic storm eagle crackling with lightning",
    "Sylvarche": "majestic ancient forest stag whose antlers are a living tree",
    "Glacivore": "majestic ice wolf with crystal armor",
    "Chronoptère": "majestic clockwork moth with hourglass wings",
    "Néantor": "majestic cosmic void beast with galaxy fur",
    "Aurèle l'Immortelle": "majestic immortal golden priestess with a halo",
    "Kaelith, Gardien des Seuils": "majestic guardian of portals holding a glowing gate key",
    "Sélénor le Dernier Mage": "majestic old archmage with a moonstone staff",
    "Ysolde Brise-Étoiles": "majestic warrior shattering a falling star with a great sword",
    # Épiques
    "Pyralis": "fire salamander-dragon", "Hydromance": "water serpent mage creature",
    "Fulgurion": "lightning cheetah", "Basaltor": "basalt rock golem turtle", "Noctifère": "night bat with starry wings",
    "Cristalame": "crystal-bladed mantis", "Orageon": "thundercloud ram", "Mirelune": "mirror-moon jellyfish",
    "Sabrecorne": "sabre-horned rhino beetle", "Ronceroi": "bramble king boar", "Cendrolithe": "ash stone golem",
    "Aquilarc": "eagle archer bird with a bow-shaped crest", "Vortexis": "wind vortex manta ray",
    "Sépulcrin": "friendly ghost lantern spirit", "Émeraudon": "emerald scaled drake",
    "Marévore": "tidal shark-whale", "Solsticien": "sun phoenix chick", "Givrespectre": "frost wisp spirit",
    "Thaïs, Lame d'Aube": "dawn swordswoman with a glowing sword", "Bram Cœur-de-Fer": "iron-hearted dwarf knight",
    "Liora la Tisseuse d'Orage": "storm weaver sorceress", "Oren le Chasseur d'Ombres": "shadow hunter archer",
    "Maëlis l'Archère d'Argent": "silver archer", "Doran le Briseur de Rocs": "rock-breaking giant with a hammer",
    "Isaure la Prêtresse des Marées": "tide priestess with a coral staff",
    "Vesper le Voleur de Lunes": "moon thief with a starry cloak",
    "Calixte le Chevalier Errant": "wandering knight with a plumed helmet",
    "Nahia la Dompteuse de Bêtes": "beast tamer with a whip and a pet",
}
RARITY_ACCENT = {
    0: "", 1: "", 2: "subtle magical sparkles,",
    3: "epic, dynamic pose, magical glow,", 4: "legendary, heroic pose, radiant aura, ornate details,",
}
FEMININE = ("la ", "l'Apprentie", "l'Éclaireuse", "l'Archère", "Immortelle")


def describe(card):
    name = card["name"]
    r = card["rarity"]
    if name in MANUAL:
        subject = MANUAL[name]
        if card["family"] == "hero":
            subject = f"human {subject}"
    elif card["family"] == "hero":
        role = next((v for k, v in sorted(ROLE_EN.items(), key=lambda kv: -len(kv[0])) if k in name), "adventurer")
        gender = "female" if any(f in name for f in FEMININE) else "male"
        subject = f"{gender} human {role}, {HERO_STAGE[r]}, chibi proportions"
    else:
        stem = max((s for s in list(ANIMALS) + list(ELEMENTS) if name.startswith(s)), key=len)
        if stem in ANIMALS:
            subject = f"{ANIMALS[stem]} creature, {STAGE[r]}"
        else:
            subject = f"small elemental creature made of {ELEMENTS[stem]}, {STAGE[r]}"
    accent = RARITY_ACCENT[r]
    return f"{subject}, {accent} {STYLE}".replace("  ", " ")


def main():
    out = ROOT / "docs/prompts_illustrations.csv"
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["numero", "fichier", "nom", "famille", "rarete", "prompt", "prompt_negatif"])
        labels = ["Commune", "Peu commune", "Rare", "Épique", "Légendaire"]
        for c in CARDS:
            w.writerow([c["id"], f"{c['id']:03d}.png", c["name"],
                        "Héros" if c["family"] == "hero" else "Créature", labels[c["rarity"]],
                        describe(c), NEGATIVE])
    print("écrit", out)


if __name__ == "__main__":
    main()
