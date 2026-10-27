# Journal des versions

## 0.9.0 – 27/10/2026 (fin de soirée) – le monde prend vie
- Décors générés par Clem dans le jeu : un sol texturé par étage (vallée, prairie, plateau, roche,
  neige, dalles des tours), arbres, buissons, fleurs, champignons, rochers et cristaux selon l'étage,
  coffres, sanctuaires, ruines, pierres runiques, pièces, boules de feu, explorateur (face, dos,
  profil, attaque) et ennemis. Le guide montre les mêmes images.
- 15 dernières secondes : le chrono passe au centre, un peu plus bas, plus grand, en rouge, bat
  chaque seconde, avec un son d'alerte unique.
- Sanctuaires : gardiens toujours au même étage que l'autel (3 cases au plus), qui restent près de
  leur poste ; en version élite avec un anneau doré, reliés à l'autel par un fil doré.

## 0.8.0 – 27/10/2026 (nuit) – confort et fluidité
- Fluidité : chaque son créait un lecteur audio jamais libéré (ralentissement au fil de la run) ;
  ils sont maintenant réutilisés. Le sol est dessiné une fois par zone puis rejoué ; les ennemis et
  pièces hors écran ne sont plus ni calculés ni dessinés ; particules allégées.
- Carte gagnée : ~0,4 s au centre, puis elle file en petit dans le coin haut droit.
- Badge « Nouveau » collé dans le coin haut droit de la carte.
- Guide (bouton ? en haut) : chaque lieu expliqué avec son dessin du jeu (sanctuaire : les points
  au-dessus = gardiens à vaincre), pièces, ennemis, vies, étages.
- Roue crantée ⚙ : volume, vibrations, compte en ligne, guide.
- Connexion proposée dans une fenêtre au premier lancement ; le Profil ne garde que les statistiques.

## 0.7.0 – 27/10/2026 (soir) – retours de playtest
- Cartes plus rares dans le monde : coffres simples sur 6 % des chunks (au lieu de 18 %) et jamais à
  moins de 3 chunks du départ. Sanctuaires et ruines plus fréquents (10 % chacun), tours 6 %.
- Ruines : 2 ennemis gardent chaque pierre runique.
- L'attaque touche une cible un étage plus haut ou plus bas (même portée).
- Pièces : au sol (parfois en tas de 5), +2 par ennemi vaincu, +10 par lieu ouvert. Compteur dans
  le HUD, le récapitulatif et la barre du haut.
- Boutique → Énergies : +1 run aujourd'hui pour 60 pièces, puis +40 à chaque achat, 5 par jour au plus,
  quand les runs du jour sont épuisées. Aussi depuis le bouton Jouer.
- Illustrations : les zones de fond blanc enfermées dans le dessin (entre les jambes, entre un bras et
  une arme…) sont retirées, et tout le dessin, ombre comprise, tient dans le rond de fond.
- Prompts ComfyUI pour les sols, décors, lieux, pièces, le personnage jouable et les ennemis
  (`docs/prompts_decors.csv`, `comfy_batch.py --decors`).
- Connexion : messages justes quand Supabase limite l'envoi d'e-mails ; la synchro ne reste plus bloquée.

## 0.6.0 – 27/10/2026 (après-midi)
- En ligne : schéma de la base (`supabase/schema.sql`) avec RLS — profils créés automatiquement à
  l'inscription avec un code ami unique, collection (carte + variante) ; chacun ne voit et n'ajoute que
  ses propres cartes, rien ne peut être modifié ni supprimé depuis l'appli. Testé sur PostgreSQL 16.
- Connexion sans mot de passe dans le Profil : on saisit son e-mail, on reçoit un code à 6 chiffres
  (ou un lien magique sur le web). Affiche le compte, le code ami en ligne et l'état de la synchro.
- Synchro de la collection : union entre l'appareil et le serveur (rien n'est jamais supprimé), au
  démarrage, à la connexion, sur le bouton « Synchroniser » ; les cartes d'une run partent en ligne à la fin.
- APK : le lien « Sign in » de l'e-mail ouvre directement l'appli et connecte (plus besoin de code).
- `docs/SUPABASE.md` : les 2 réglages à faire une fois dans le tableau de bord Supabase.

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
