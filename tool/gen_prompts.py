"""Génère les prompts d'illustration des 300 cartes (style cartoon coloré).

Styles : petites créatures mignonnes et rondes ; créatures rares = bêtes puissantes ;
épiques/légendaires = monstres épiques (effrayants si leur nom est sombre) ; héros = héroïques, « durs à cuire ».

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
# Créatures puissantes (rares) : plus de bébé mignon, une vraie bête qui en impose.
FIERCE_STYLE = (
    "stylized cartoon creature for a mobile game, powerful adult beast, fierce determined eyes, "
    "sharp claws, horns or spikes, muscular dynamic pose, thick clean dark outlines, bold cel shading, "
    "vibrant saturated colors, strong readable silhouette, full body, centered, 3/4 front view, "
    "plain white background, original design, not chibi, not baby-like"
)
# Créatures épiques et légendaires : imposantes, intimidantes, épiques.
EPIC_STYLE = (
    "epic stylized cartoon monster for a mobile game, huge imposing creature, intimidating fierce glare, "
    "dramatic dynamic pose, detailed armor-like features, thick clean dark outlines, dramatic cel shading, "
    "vibrant saturated colors, strong readable silhouette, full body, centered, 3/4 front view, "
    "plain white background, original design, not cute, not chibi"
)
# Noms sombres (ombre, néant, abysses, tombe, nuit…) : la créature doit faire peur, dès « Rare ».
DARK_ROOTS = ("Ombr", "Néant", "Sépulcr", "spectre", "Abyss", "abysse", "Noct", "Nuit", "Mort", "Crâne", "Cauchemar")
DARK_MOOD = "menacing and scary, dark ominous aura, glowing eyes,"
# Légendaires lumineux : grandioses plutôt qu'effrayants.
MAJESTIC_MOOD = "awe-inspiring and majestic, godlike presence,"
# Suffixe du nom d'une créature « Rare » → trait marquant, pour que chacune ait sa silhouette.
SUFFIX_TRAIT = {
    "orn": "with large curved horns", "axe": "with axe-like blade limbs", "oros": "massive heavily armored body",
    "idor": "regal with ornate golden markings", "ix": "sleek, fast and agile predator", "anthe": "elegant with sharp thorny petals",
}
# Animaux juvéniles → version adulte pour les créatures puissantes.
ADULT = {"bear cub": "bear", "deer fawn": "stag", "tadpole": "giant frog", "fanged critter": "fanged beast",
         "clawed critter": "clawed beast"}

# Héros : toujours cartoon, mais héroïque et impressionnant (pas « kawaii »).
HERO_STYLE = (
    "stylized cartoon hero character for a mobile game, heroic proportions about six heads tall, "
    "adult, confident fierce expression, tough and impressive, dynamic battle-ready pose, detailed gear, "
    "thick clean dark outlines, bold cel shading, vibrant saturated colors, strong readable silhouette, "
    "full body, centered, 3/4 front view, plain white background, original design, not chibi, not childlike"
)
FLUX_SUFFIX = (
    ", a single character only, isolated on a plain pure white background, no text, no letters, "
    "no frame, no border, no scenery, no floating objects, the whole character including wings and weapons "
    "fully inside the image with a white margin, soft round shadow on the ground under the character, flat 2D illustration"
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
    2: "fully evolved powerful creature, imposing and battle-ready",
}

ROLE_EN = {
    "Vagabond": "grizzled wandering swordsman with a worn hooded cloak and a battered blade",
    "Vagabonde": "grizzled wandering swordswoman with a worn hooded cloak and a battered blade",
    "Apprenti": "determined young battle mage with a glowing spellbook and crackling hands",
    "Apprentie": "determined young battle mage with a glowing spellbook and crackling hands",
    "Pêcheur": "rugged deep-sea fisherman who hunts sharks, holding a huge harpoon, heavy net on the shoulder, scars, salt-stained coat",
    "Pêcheuse": "rugged deep-sea fisherwoman who hunts sharks, holding a huge harpoon, heavy net on the shoulder, scars, salt-stained coat",
    "Bûcheron": "burly lumberjack with a massive double-bladed axe and plaid shirt",
    "Bûcheronne": "burly lumberjack with a massive double-bladed axe and plaid shirt",
    "Garde": "armored town guard with a long spear and a big tower shield",
    "Éclaireur": "agile scout with a short bow, spyglass and wind-swept scarf",
    "Éclaireuse": "agile scout with a short bow, spyglass and wind-swept scarf",
    "Forgeron": "muscular blacksmith with a huge glowing forge hammer and leather apron",
    "Forgeronne": "muscular blacksmith with a huge glowing forge hammer and leather apron",
    "Berger": "tough mountain shepherd with a heavy iron crook and wolf-fur cloak",
    "Bergère": "tough mountain shepherd with a heavy iron crook and wolf-fur cloak",
    "Cueilleur": "wilderness forager with a machete, herb satchel and camouflage cloak",
    "Cueilleuse": "wilderness forager with a machete, herb satchel and camouflage cloak",
    "Marchand": "shrewd traveling merchant with a loaded backpack and a hidden dagger",
    "Marchande": "shrewd traveling merchant with a loaded backpack and a hidden dagger",
    "Rôdeur": "hooded ranger drawing a longbow", "Rôdeuse": "hooded ranger drawing a longbow",
    "Mercenaire": "battle-scarred mercenary with a greatsword on the shoulder",
    "Alchimiste": "alchemist with a bandolier of explosive bubbling potions",
    "Duelliste": "elegant duelist with a rapier in a fierce fencing stance",
    "Pisteur": "fur-hooded tracker with a bow and hunting knife", "Pisteuse": "fur-hooded tracker with a bow and hunting knife",
    "Moine": "martial arts monk in fighting stance with glowing fists",
    "Moniale": "martial arts monk in fighting stance with glowing fists",
    "Corsaire": "swashbuckling pirate captain with a cutlass and flintlock pistol",
    "Barde": "battle bard with a lute on the back and a rapier in hand",
    "Paladin": "paladin in shining heavy armor with a glowing warhammer",
    "Paladine": "paladin in shining heavy armor with a glowing warhammer",
    "Mage des Cendres": "ash mage conjuring swirling embers and smoke",
    "Maître-Lame": "blade master wielding two katanas", "Maîtresse-Lame": "blade master wielding two katanas",
    "Druide": "druid with an antler staff and armor made of bark and leaves",
    "Druidesse": "druid with an antler staff and armor made of bark and leaves",
    "Arcaniste": "arcanist surrounded by floating glowing runes",
    "Gardien des Ruines": "ancient ruins guardian in stone armor with a massive shield",
    "Gardienne des Ruines": "ancient ruins guardian in stone armor with a massive shield",
    "Chasseur de Primes": "bounty hunter with a heavy crossbow and a long leather coat",
    "Chasseuse de Primes": "bounty hunter with a heavy crossbow and a long leather coat",
    "Chevaucheur de Wyverne": "wyvern rider in dragon-scale armor with a long lance",
    "Chevaucheuse de Wyverne": "wyvern rider in dragon-scale armor with a long lance",
}
HERO_STAGE = {0: "seasoned adventurer", 1: "battle-hardened veteran", 2: "renowned champion"}

MANUAL = {
    # Légendaires
    "Astrelune": "majestic celestial fox-like creature made of starlight and a crescent moon",
    "Volcarion": "colossal volcanic dragon-lion with a roaring lava mane and obsidian horns",
    "Abyssiel": "colossal abyssal sea serpent with rows of fangs, eerie glowing bioluminescent patterns",
    "Tempestor": "giant storm eagle with huge wings crackling with lightning",
    "Sylvarche": "majestic ancient forest stag whose antlers are a living tree",
    "Glacivore": "giant ice wolf with jagged crystal armor and frozen fangs",
    "Chronoptère": "majestic clockwork moth with hourglass wings",
    "Néantor": "colossal cosmic void beast with galaxy fur, many glowing eyes and black tendrils",
    "Aurèle l'Immortelle": "majestic immortal golden priestess with a halo",
    "Kaelith, Gardien des Seuils": "majestic guardian of portals holding a glowing gate key",
    "Sélénor le Dernier Mage": "majestic old archmage with a moonstone staff",
    "Ysolde Brise-Étoiles": "majestic warrior shattering a falling star with a great sword",
    # Épiques
    "Pyralis": "fire salamander-dragon", "Hydromance": "water serpent mage creature",
    "Fulgurion": "lightning-fast cheetah wreathed in electricity", "Basaltor": "massive basalt rock golem turtle with a volcanic shell", "Noctifère": "giant night bat with starry wings and sharp fangs",
    "Cristalame": "giant crystal-bladed praying mantis", "Orageon": "thundercloud ram with huge lightning horns", "Mirelune": "giant mirror-moon jellyfish with long glowing stinging tentacles",
    "Sabrecorne": "sabre-horned rhino beetle", "Ronceroi": "huge bramble king boar with thorny tusks and a crown of thorns", "Cendrolithe": "ash stone golem",
    "Aquilarc": "eagle archer bird with a bow-shaped crest", "Vortexis": "wind vortex manta ray",
    "Sépulcrin": "eerie ghost lantern wraith with hollow glowing eyes and ghostly chains", "Émeraudon": "emerald scaled dragon drake with spread wings",
    "Marévore": "colossal tidal shark-whale with rows of teeth", "Solsticien": "blazing sun phoenix with wings of fire", "Givrespectre": "frost wraith spirit with icy claws",
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
# Prénoms féminins dont le titre est épicène (« l'Alchimiste », « l'Arcaniste »…) ou sans article.
FEMALE_FIRST_NAMES = {"Rosa", "Rhéa", "Thaïs", "Ysolde", "Aurèle"}


def hero_gender(name):
    first = name.replace(",", " ").split()[0]
    if first in FEMALE_FIRST_NAMES or any(f in name for f in FEMININE):
        return "female"
    return "male"


def describe(card):
    name = card["name"]
    r = card["rarity"]
    if name in MANUAL:
        subject = MANUAL[name]
        if card["family"] == "hero":
            subject = f"{hero_gender(name)} human {subject}"
    elif card["family"] == "hero":
        role = next((v for k, v in sorted(ROLE_EN.items(), key=lambda kv: -len(kv[0])) if k in name), "adventurer")
        subject = f"{hero_gender(name)} human {role}, {HERO_STAGE[r]}"
    else:
        stem = max((s for s in list(ANIMALS) + list(ELEMENTS) if name.startswith(s)), key=len)
        if stem in ANIMALS:
            animal = ANIMALS[stem]
            if r >= 2:
                animal = ADULT.get(animal, animal)
            subject = f"{animal} creature, {STAGE[r]}"
        else:
            size = "small" if r < 2 else "large"
            subject = f"{size} elemental creature made of {ELEMENTS[stem]}, {STAGE[r]}"
        if r == 2:
            trait = next((v for k, v in sorted(SUFFIX_TRAIT.items(), key=lambda kv: -len(kv[0])) if name.endswith(k)), "")
            if trait:
                subject += f", {trait}"
    return f"{subject}, {mood(card)}{RARITY_ACCENT[r]} {style_for(card)}".replace("  ", " ")


def is_dark(card):
    return any(k.lower() in card["name"].lower() for k in DARK_ROOTS)


def style_for(card):
    """Petites créatures (commune, peu commune) : mignonnes. Rares : bêtes puissantes. Épiques+ : monstres épiques."""
    if card["family"] == "hero":
        return HERO_STYLE
    r = card["rarity"]
    return STYLE if r < 2 else FIERCE_STYLE if r == 2 else EPIC_STYLE


def mood(card):
    if card["family"] == "hero" or card["rarity"] < 2:
        return ""
    if is_dark(card):
        return DARK_MOOD + " "
    if card["rarity"] == 4:
        return MAJESTIC_MOOD + " "
    return ""


def negative(card):
    """Prompt négatif (générateurs autres que FLUX) : « scary » n'est exclu que pour les créatures mignonnes."""
    if style_for(card) == STYLE:
        return NEGATIVE
    return NEGATIVE.replace("gore, scary,", "gore, cute, chibi, baby,")


def main():
    out = ROOT / "docs/prompts_illustrations.csv"
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["numero", "fichier", "nom", "famille", "rarete", "prompt", "prompt_negatif"])
        labels = ["Commune", "Peu commune", "Rare", "Épique", "Légendaire"]
        for c in CARDS:
            w.writerow([c["id"], f"{c['id']:03d}.png", c["name"],
                        "Héros" if c["family"] == "hero" else "Créature", labels[c["rarity"]],
                        describe(c), negative(c)])
    print("écrit", out)

    # Version FLUX : pas de prompt négatif (FLUX l'ignore), consignes intégrées au prompt.
    flux = ROOT / "docs/prompts_flux.csv"
    with flux.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["numero", "fichier", "nom", "prompt"])
        for c in CARDS:
            w.writerow([c["id"], f"{c['id']:03d}.png", c["name"], describe(c) + FLUX_SUFFIX])
    print("écrit", flux)


if __name__ == "__main__":
    main()
