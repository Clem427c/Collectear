# Feuille de route Collectear

Légende : [x] fait · [ ] à faire · (P) provisoire

## Étape 1 – Prototype jouable (en cours)
- [x] Projet Flutter + Flame, CI GitHub Actions (tests, build web + APK, Pages, release APK)
- [x] Terrain infini procédural en niveaux de hauteur (seed par run)
- [x] Joueur : déplacement (joystick / clavier), saut (+1 niveau), attaque, esquive
- [x] Ennemis : corps à corps et tir à distance, attaques télégraphiées, restent sur leur niveau
- [x] Spawn / despawn par chunks, difficulté selon la distance
- [x] Coffres (lieux) placés sur les points hauts
- [x] Run de 2 min : fin par mort (2 coups), 3 cartes ou chrono
- [x] Carte tous les 10 kills ou dans un coffre ; tirage pondéré par rareté
- [x] Récapitulatif, collection locale, bestiaire, limite de 10 runs/jour
- [x] Compagnon de run, boost fixe par carte choisi selon son nom
- [x] Terrain garanti sans blocage (écart max d'1 niveau entre cases voisines)
- [x] 3 vies, +1 vie tous les 3 kills si une vie a été perdue
- [x] Interface à onglets : Profil, Boutique, Jouer, Bestiaire, Social
- [x] Prototypes visuels : boutique (cosmétiques), échanges, combats (données d'exemple)
- [x] Premiers retours de playtest de Clem (blocage terrain, vies, interface)
- [ ] Nouveaux retours de playtest → réglages (vitesses, densité d'ennemis, zoom)
- [ ] Feedback : sons, vibrations, effets de coup, écran de début de run
- [ ] Mini-carte ou boussole vers le coffre le plus proche

## Étape 2 – Boucle de jeu
- [ ] Types de lieux du GDD : sanctuaire (vaincre les ennemis autour), tour, ruine, coffre rare
- [ ] Variantes procédurales des cartes (teinte, motifs, shiny) + stats légèrement variées
- [ ] Fiche de style IA + prompts des 300 cartes (pour Clem) ; intégration des illustrations
- [ ] Écran de carte détaillé, animations d'obtention

## Étape 3 – En ligne (Supabase)
- [ ] Comptes (e-mail, Google), sauvegarde de la collection côté serveur
- [ ] Validation serveur des récompenses (anti-triche)
- [ ] Amis (code ami), échanges carte contre carte
- [ ] Profil d'explorateur, classement entre amis

## Étape 4 – Monétisation
- [ ] AdMob : run bonus au-delà de 10/jour, résurrection (vidéos récompensées)
- [ ] Skins cosmétiques, achats intégrés, option sans pub

## Étape 5 – Lancement
- [ ] Combats entre amis (format à définir par Clem)
- [ ] Publication Google Play, puis App Store, puis web

## Décisions de Clem
- Boost fixé par carte, cohérent avec son nom (tool/assign_boosts.py).
- Le compteur de 10 ennemis repart à zéro à chaque run.
- Héros et créatures ne diffèrent que par le style visuel (héros = humanoïde, créature = non humanoïde).
- 3 vies ; une vie rendue tous les 3 kills si on en a perdu au moins une.

## Questions pour Clem
- Combats entre amis : format à définir (écran de composition d'équipe prototypé).
- Échanges : uniquement entre cartes de même rareté ? (proposé dans le prototype)
