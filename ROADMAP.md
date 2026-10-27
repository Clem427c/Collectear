# Feuille de route Collectear

Légende : [x] fait · [ ] à faire · (P) provisoire

## Étape 1 – Prototype jouable (en cours)
- [x] Projet Flutter + Flame, CI GitHub Actions (tests, build web + APK, Pages, release APK)
- [x] Terrain infini procédural en niveaux de hauteur (seed par run)
- [x] Joueur : déplacement (joystick / clavier), saut (+1 niveau), attaque, esquive
- [x] Ennemis : corps à corps et tir à distance, attaques télégraphiées, restent sur leur niveau
- [x] Spawn / despawn par chunks, difficulté selon la distance
- [x] Coffres (lieux) placés sur les points hauts
- [x] Run de 2 min : fin par mort (3 vies), 3 cartes ou chrono
- [x] Carte tous les 10 kills ou dans un coffre ; tirage pondéré par rareté
- [x] Récapitulatif, collection locale, bestiaire, limite de 10 runs/jour
- [x] Compagnon de run, boost fixe par carte choisi selon son nom
- [x] Terrain garanti sans blocage (écart max d'1 niveau entre cases voisines)
- [x] 3 vies, +1 vie tous les 3 kills si une vie a été perdue
- [x] Interface à onglets : Profil, Boutique, Jouer, Bestiaire, Social
- [x] Prototypes visuels : boutique (cosmétiques), échanges, combats (données d'exemple)
- [x] Premiers retours de playtest de Clem (blocage terrain, vies, interface)
- [ ] Nouveaux retours de playtest → réglages (vitesses, densité d'ennemis, zoom)
- [x] Sensations : sons, vibrations, particules, flash de dégâts, compte à rebours, carte obtenue animée
- [x] Boost Portée (5e boost)

## Étape 2 – Boucle de jeu
- [x] Types de lieux du GDD : sanctuaire (4 gardiens), tour (pyramide à gravir), ruine (3 runes), coffre rare (loin du départ)
- [x] Variantes procédurales des cartes (teinte, motifs, shiny, Dorée/Cristal/Ombre) + stats ±4 %
- [x] Fiche de style IA + prompts des 300 cartes (docs/) ; intégration automatique depuis art/raw/
- [x] Illustrations : les 300 cartes générées par Clem avec `tool/comfy_batch.py --auto` (nuit du 26 au 27/10)
- [x] Revue des 300 images (27/10) : 16 à refaire, listées dans « Questions pour Clem »
- [x] Écran de carte détaillé (grande illustration qui flotte et tourne au toucher, stats avec écart de la variante,
  qualité en étoiles, boost, défilement entre ses exemplaires) — depuis le bestiaire et le récapitulatif
- [ ] Illustrations : intégrer les 16 images refaites quand Clem les aura poussées (rien à coder, la CI les traite)

## Étape 3 – En ligne (Supabase) — prochaine étape
Clem a créé le projet Supabase et ajouté les secrets GitHub `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` (26/10).
- [x] Secrets vérifiés en CI sans les afficher (présents, URL https, clé publishable) et injectés au build (27/10)
- [x] `supabase_flutter` branché : client initialisé au démarrage, état du serveur dans le Profil
- [ ] **Prochaine session** : schéma SQL (profils, collection) avec RLS dans `supabase/schema.sql`, à coller par Clem
  dans l'éditeur SQL de Supabase ; puis connexion e-mail (lien magique) et synchro de la collection
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
- Exploration 100 % libre : aucune boussole, mini-carte ni indication vers les lieux.
- Échanges libres, négociés entre joueurs, sans restriction de rareté.
- 5e boost « Portée » : attaque de plus loin (langues, tentacules, archers, mages…).
- Combats entre amis : Clem a ses idées, on s'y attaque à la toute fin.
- Style des illustrations : cartoon coloré, façon jeu mobile grand public. Petites créatures (communes, peu communes) mignonnes et rondes ; créatures rares, épiques et légendaires plus impressionnantes (effrayantes si leur nom est sombre) ; héros héroïques, « durs à cuire », pas enfantins.

## Questions pour Clem
### Illustrations à refaire (revue du 27/10)
Les 284 autres images sont bonnes (fond blanc, un seul personnage, style respecté, rares/épiques/légendaires
impressionnantes). Attention : supprimer l'image et relancer redonnait **exactement la même image** (graine fixe).
Pour refaire, une seule commande (nouvelle graine, remplace les images puis pousse sur GitHub) :
`py tool\comfy_batch.py --redo 29,64,67,72,136,155,223,277,291,297,300`
(ajoute 86,189,241,204,262 si tu veux aussi refaire la priorité basse).
Les prompts ont été corrigés : genre des héroïnes (Rosa, Rhéa, Nahia… sortaient en homme à cause d'un bug
de détection), et pour tous : « pas de décor, pas d'objets flottants, personnage entier dans l'image ».

Priorité haute (défaut visible en jeu) :
- 029 Tremblichon : un trait parasite (fil gris) flotte au-dessus de la créature.
- 064 Mélusine la Bergère : une tête de hache flotte à côté d'elle, détachée.
- 067 Firmin le Cueilleur : décor d'arbres derrière lui (le fond n'est pas uni).
- 072 Gaïa la Forgeronne : marteaux et enclume qui flottent autour d'elle.
- 136 Achille l'Alchimiste : texte « 7IL » sur la fiole.
- 155 Rosa l'Alchimiste : dessinée comme un homme musclé (nom féminin).
- 223 Rhéa l'Arcaniste : dessinée comme un homme barbu (nom féminin), + glyphes qui ressemblent à des chiffres.
- 277 Nahia la Dompteuse : dessinée comme un homme barbu (nom féminin).
- 291 Abyssiel (Légendaire) : une deuxième petite tête/créature en bas à droite.
- 297 Tempestor (Légendaire) : les ailes sont coupées par les bords de l'image.
- 300 Kaelith, Gardien des Seuils (Légendaire) : les ailes sont coupées par les bords de l'image.

Priorité basse (à toi de juger) :
- 086 Zéphyr l'Apprenti : un petit objet (lanterne) flotte à côté de lui.
- 189 Cervouille : une oreille détachée flotte à droite.
- 241 Wilhelm le Druide : un petit fragment (griffe) flotte à ses pieds.
- 204 Hélia la Pisteuse : visage enfantin, peu « dure à cuire ».
- 262 Calixte le Chevalier (Épique) : petit et trapu, peu impressionnant pour une épique.

### En ligne
- Pour la connexion Google, il faudra créer des identifiants OAuth dans Google Cloud et les coller dans
  Supabase (Authentication → Providers → Google). Je commencerai par l'e-mail (aucun réglage). Tu valides ?
- Dans le Profil, la ligne « Compte en ligne » doit afficher « Serveur joignable » : dis-moi si ce n'est pas le cas.

### Illustrations (suite)
Remarque : les 4 bûcherons (035 Hugo, 065 Pio, 070 Milo, 079 Anatole) se ressemblent beaucoup
(barbe rousse, chemise à carreaux, hache). Faut-il en différencier certains (âge, coiffure, couleurs) ?
