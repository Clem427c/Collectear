# Journal des versions

## 0.5.0 – 27/10/2026
- Revue des 300 illustrations générées par Clem : 284 validées, 16 à refaire (liste dans ROADMAP.md).
  Bug corrigé dans les prompts : certaines héroïnes (Rosa, Rhéa, Nahia…) étaient demandées en homme.
  Prompts renforcés : pas de décor, pas d'objets flottants, personnage entier dans l'image.
  Nouvelle option `comfy_batch.py --redo 29,64,…` : refait des cartes avec une nouvelle graine
  (avant, supprimer et relancer redonnait exactement la même image).
- Écran de carte détaillé en plein écran : grande illustration teintée selon la variante, qui flotte
  et fait un tour sur elle-même quand on la touche ; barres de PV/ATQ/DEF avec l'écart de la variante
  (±4 %) ; qualité de l'exemplaire en étoiles (1 à 5) ; motif, finition, shiny ; on fait défiler ses
  exemplaires. S'ouvre depuis le bestiaire et depuis le récapitulatif de run.
- En ligne : secrets Supabase vérifiés en CI (sans les afficher) et injectés dans les builds web et APK,
  client Supabase initialisé au démarrage, état du serveur affiché dans le Profil. Permission Internet
  ajoutée à l'APK.

## 0.4.0 – 26/10/2026
- Variantes procédurales : chaque carte obtenue a sa teinte, son motif (rayures, taches, anneaux, étoiles),
  parfois un éclat Shiny (1/40) ou une finition Dorée (1/100), Cristal ou Ombre (1/150), et des stats à ±4 %
  (sans jamais dépasser la rareté supérieure). Le bestiaire montre tous ses exemplaires.
- Illustrations : fiche de style (docs/STYLE_ILLUSTRATIONS.md), 300 prompts (docs/prompts_illustrations.csv),
  traitement automatique des images déposées dans art/raw/ (détourage, recadrage, 512×512) et teinte des variantes.

## 0.3.0 – 26/10/2026
- 5e boost « Portée » : le joueur attaque de plus loin (33 cartes : grenouilles, pieuvres, lianes, archers, mages…).
- Échanges libres (plus de suggestion de même rareté) ; exploration sans aucune indication.
- Compte à rebours 3-2-1-GO avec l'objectif et le compagnon, sons synthétisés (coups, saut, esquive,
  tirs, coffres, cartes…), bouton son, vibrations sur Android, particules, flash rouge quand on est touché,
  animation « Nouvelle carte ! ».
- Lieux : sanctuaire (vaincre ses 4 gardiens pour réveiller l'autel), tour (pyramide de pierre à gravir
  saut après saut, coffre au sommet), ruine (activer 3 pierres runiques pour l'ouvrir), coffre rare
  (violet, loin du départ, meilleures chances de rareté).

## 0.2.0 – 26/10/2026
Retours du premier playtest de Clem.
- Terrain : deux cases voisines ne diffèrent jamais de plus d'un niveau, on ne peut plus être coincé.
- 3 vies (4 avec le boost Résistance) ; +1 vie tous les 3 ennemis tués si une vie a été perdue.
- Boost de compagnon fixe pour chacune des 300 cartes, choisi selon le nom.
- Nouvelle interface à onglets façon jeu mobile : Profil, Boutique, Jouer (centre), Bestiaire, Social.
- Boutique prototype (skins, cadres, sans pub, gemmes), bestiaire en grille de cartes avec filtres,
  social prototype (amis, échanges, combats) avec données d'exemple, profil d'explorateur avec statistiques.
- Zone de départ sans ennemis, 4 s de répit au début, hauteurs plus lisibles.

## 0.1.0 – 26/10/2026
Premier prototype jouable.
- Monde infini en niveaux de hauteur, nouveau monde à chaque run.
- Joueur : déplacement, saut d'un niveau, attaque, esquive. Contrôles tactiles et clavier.
- Ennemis corps à corps et à distance, coffres sur les hauteurs.
- Runs de 2 minutes, 3 conditions de fin, cartes gagnées (10 kills ou coffre), récapitulatif.
- Collection locale, bestiaire des 300 cartes, compagnon de run, limite de 10 runs par jour.
- CI : tests, build web + APK, mise en ligne automatique.
