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
- [x] Compagnon de run (P : boost déduit du numéro de carte)
- [ ] Retours de playtest de Clem → réglages (vitesses, densité d'ennemis, zoom)
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

## Questions pour Clem
- Boost du compagnon : fixé par espèce ou tiré selon la variante ? (actuellement : numéro de carte % 4)
- Le compteur de 10 ennemis repart-il à zéro à chaque run ? (actuellement : oui)
- Héros vs créatures : quelle différence en dehors du boost ?
