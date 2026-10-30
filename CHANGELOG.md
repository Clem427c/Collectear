# Journal des versions

## 0.17.1 – 30/10/2026 (après-midi) – pseudos sans gros mots
- Pseudo (première connexion et changement depuis le Profil) : les gros mots et insultes (français et
  anglais) sont refusés, même déguisés avec des chiffres, des points ou des lettres répétées
  (« C0NN4RD », « s.a.l.o.p.e », « connnnard »). Les mots qui en contiennent un par hasard restent
  acceptés (« Computer », « Technique », « Conan », « Crocouille »…) ; les 300 noms de cartes sont testés.
  Provisoire : vérifié par l'appli seulement, pas encore par le serveur.

## 0.17.0 – 30/10/2026 – cadres de cartes
- Boutique → Cadres de cartes : 5 cadres (givré, de lave, de lierre, holographique, royal) achetables avec
  les pièces (250 à 1 000), à porter ou changer quand on veut (« Porter » / « Porté »). Le cadre porté
  entoure toutes les cartes de sa collection : bestiaire, compagnon de run, cartes du récapitulatif.
  Purement cosmétique ; les cartes des amis gardent leur bord blanc.
- Guide → Pièces : mention des skins et des cadres.
- CI : le test de fumée web fait aussi une capture des cadres dans la Boutique.

## 0.16.0 – 29/10/2026 – consentement des pubs, skins d'explorateur
- Pubs (Android) : au premier lancement en Europe, le formulaire de consentement de Google (RGPD)
  s'affiche avant toute pub ; AdMob ne démarre qu'après. ⚙ Paramètres → Publicités : état des vidéos
  et « Choix de confidentialité » pour changer d'avis. Sans consentement : vidéo simulée tant que ce
  sont les identifiants de test, aucune vidéo avec les vrais.
- Boutique → Skins d'explorateur : 6 skins (Éclaireur azur, Braise, Sylve, Corail, Nuit étoilée,
  Or royal) achetables avec les pièces (300 à 1 200), à porter ou changer quand on veut. En run,
  la cape de l'explorateur prend les couleurs du skin porté (images recolorées automatiquement en CI
  à partir des 4 poses, ombres et reflets conservés). Purement cosmétique.
- CI : le test de fumée web fait aussi une capture de la Boutique.

## 0.15.0 – 29/10/2026 – vidéos récompensées (provisoire)
- Plus aucune run ? Bouton « VIDÉO · +1 RUN » sous le bouton Jouer : une courte vidéo = une run de
  plus, 3 fois par jour au plus.
- Tombé au combat : le jeu se fige et propose « Revenir (vidéo) » : on repart avec 1 vie (et 2,5 s
  d'invincibilité), une fois par run. « Terminer la run » garde cartes et pièces comme avant.
- Android : vraies vidéos AdMob, avec les identifiants de TEST de Google (vidéos « Test Ad ») tant que
  Clem n'a pas son compte AdMob. Web : vidéo simulée de 5 s pour tester le parcours.
- Serveur : jusqu'à 18 runs par jour (10 + 5 énergies + 3 vidéos). **À faire par Clem** : recoller
  `supabase/schema.sql`.
- Guide mis à jour (vies, pièces).

## 0.14.2 – 28/10/2026 (nuit)
- Attaque : collé à un ennemi ou en le chevauchant, le coup le touche quelle que soit la direction
  du personnage (avant, il fallait être tourné vers lui, ce qui ratait souvent au contact). À distance,
  rien ne change : l'ennemi doit être devant et à portée. Guide mis à jour.

## 0.14.1 – 28/10/2026 (soir)
- Fiche d'une carte (depuis le bestiaire) : glisser à gauche / à droite passe à la carte possédée
  suivante / précédente, dans l'ordre des numéros (les cartes pas encore obtenues sont sautées).
  Pour changer d'exemplaire : les flèches de part et d'autre des points sous l'illustration.

## 0.14.0 – 28/10/2026 (soir) – variantes spectaculaires, pseudo, test web
- Variantes bien plus visibles : motifs marqués, anneaux en ondes et étoiles en orbite (animés),
  finitions Dorée / Cristal / Ombre avec aura, cadre et reflet qui balaie la carte, Shiny avec cadre
  arc-en-ciel tournant et éclats qui scintillent.
- Guide → « Voir toutes les variantes » : n'importe quelle carte dans ses 10 apparences.
- Première connexion : on choisit son pseudo (fini les « Explorateur » qui s'ajoutent entre eux).
- Vitrine de test (`supabase/showcase.sql`) : donne à un compte les 300 cartes en 10 exemplaires.
- CI : la version web est testée à chaque build dans un navigateur (téléphone et PC) : une run est
  lancée, on vérifie que l'image bouge avec les flèches, captures dans le journal.

## 0.13.4 – 28/10/2026 (soir) – connexion et lisibilité
- Messages en bas d'écran lisibles partout (texte blanc sur fond violet foncé ; avant : gris foncé
  sur bleu nuit, par exemple « Ajoute d'abord un ami »).
- Connexion : l'écran parle maintenant du code reçu par e-mail ; il précise que le lien de l'e-mail ne
  fonctionne que sur l'appareil qui l'a demandé. `docs/SUPABASE.md` §3 : mettre le code dans l'e-mail
  (Gmail en serveur d'envoi + modèles d'e-mail).

## 0.13.3 – 28/10/2026 (soir) – étoiles des exemplaires
- Les étoiles d'un exemplaire indiquent maintenant la rareté de son apparence : 1 ★ uni, rayures ou
  taches ; 2 ★ motif étoiles ou anneaux ; 3 ★ Shiny ; 4 ★ Dorée, Cristal ou Ombre ; 5 ★ finition + Shiny.
  Avant, elles ne mesuraient que les stats, d'où un Shiny parfois moins étoilé qu'un uni.
- Les stats ont leur propre étiquette sur la fiche (« Stats −3 % » = écart moyen des trois stats).
- Le bestiaire montre et la fiche range en premier l'exemplaire le plus étoilé.
- Guide (bouton ?) : nouvelle section « Tes cartes » : exemplaires uniques, étoiles, stats, favoris, échanges.

## 0.13.2 – 28/10/2026 (soir) – sols doux
- Nouveaux sols de Clem (prompts doux) intégrés : vallée, prairie et plateau clairs, peu contrastés,
  sans contours. Comme ils sortaient tous crème très pâle, chaque étage est ramené à sa teinte (vert
  sauge, vert tendre, paille) sans toucher au motif : on distingue les hauteurs, et personnages et
  ennemis ressortent nettement.

## 0.13.1 – 28/10/2026 (soir)
- Sols régénérés par Clem intégrés (vallée, prairie, plateau). Ils sortaient encore des anciens prompts
  (la copie locale des prompts n'était pas à jour) : la vallée, toujours très sombre, reste adoucie
  automatiquement.
- `comfy_batch.py` fait un `git pull` avant de lire les prompts (option `--no-pull` pour l'éviter).

## 0.13.0 – 28/10/2026 (soir) – lisibilité et retours de Clem
- Herbe : la vallée (sol le plus courant) était trop dense et trop foncée. Elle est maintenant adoucie
  automatiquement (vert sauge clair, relief très léger) ; personnages et ennemis ressortent mieux.
  Nouveaux prompts doux pour les sols vallée, prairie et plateau, à régénérer dans ComfyUI :
  `py tool\comfy_batch.py --decors --redo 1,2,3`.
- Tours : le sommet est une plate-forme de 3×3 cases (au lieu d'une seule) ; la pyramide fait 9×9 cases.
  On voit tout de suite qu'il reste un étage à sauter pour atteindre le coffre. Guide mis à jour.
- Énergies : on peut en acheter dès qu'il en manque une (jusqu'à revenir à 10), plus seulement quand
  toutes les runs sont épuisées ; bouton « +1 énergie » aussi sous le bouton Jouer. Toujours 5 achats
  par jour au plus.

## 0.12.1 – 28/10/2026 (après-midi) – profil des amis
- Toucher un ami (ou sa ligne du classement) ouvre son profil : code ami, cartes, exemplaires, record,
  progression par rareté, et combien de cartes il a que tu n'as pas (et l'inverse).
- Sa collection en grille, filtrable (toutes / il a, pas toi / ses doublons). Toucher une carte montre
  ses exemplaires : les voir en grand, ou en demander un (l'échange s'ouvre avec la carte déjà cochée).
- Pastille rouge sur l'onglet Social de la barre du bas quand une demande d'ami ou un échange attend
  ta réponse ; amis et échanges rechargés toutes les 90 s quand l'appli est ouverte.

## 0.12.0 – 28/10/2026 (après-midi) – échanges à plusieurs cartes et favoris
- Échanges de 1 à 5 cartes de chaque côté (2 contre 1, 3 contre 2…) : on coche les cartes de chaque
  côté, l'échange se fait en une fois quand l'ami accepte.
- Favoris : étoile en haut de la fiche d'un exemplaire (bestiaire, récapitulatif de run). Une carte en
  favori porte une étoile dorée ; elle ne peut être ni offerte ni demandée par un ami tant qu'elle n'est
  pas retirée des favoris. La mettre en favori annule les propositions en attente qui la concernent.
  Les favoris sont sauvegardés en ligne et visibles par tes amis (bouton « Favori » au lieu de « Demander »).
- Serveur : nouvelle table des cartes d'un échange (migration automatique depuis la 0.11), 70 vérifications.
- **À faire par Clem** : recoller `supabase/schema.sql` (toujours sans rien supprimer).

## 0.11.0 – 28/10/2026 (midi) – amis et échanges
- Onglet Social → Amis : ton code ami (bouton copier), ajout d'un ami par son code, demandes reçues
  (accepter / refuser) et envoyées (annuler), liste de tes amis avec leur nombre de cartes, retrait.
- Échanges pour de vrai : « Proposer un échange » → tu choisis une de tes cartes et une carte de ton ami
  (badge « Nouveau » sur celles que tu n'as pas). Ton ami accepte ou refuse ; les deux cartes changent de
  main au moment de l'acceptation, et les autres propositions sur ces cartes expirent. Historique sur 30 jours.
- Pastilles rouges sur les onglets Amis et Échanges quand quelque chose attend ta réponse.
- Classement entre amis (cartes différentes, exemplaires, record d'ennemis).
- Côté serveur : tout passe par des fonctions contrôlées (pas d'écriture directe), une carte donnée ne peut
  pas revenir par la synchro ; 52 vérifications du schéma en CI.
- **À faire par Clem** : recoller `supabase/schema.sql` (sans ça, l'onglet Social affiche
  « Le serveur n'est pas encore à jour »).

## 0.10.0 – 28/10/2026 – profil en ligne et premières protections anti-triche
- Pseudo modifiable : toucher son nom dans le Profil. Enregistré sur l'appareil et en ligne ; sur un
  nouvel appareil, le pseudo choisi est retrouvé à la connexion.
- Statistiques du Profil complétées par celles du serveur (runs, ennemis, cartes, record).
- Anti-triche, 1re partie : quand on est connecté, chaque run est ouverte puis fermée par le serveur,
  qui ajoute lui-même les cartes gagnées et refuse ce qui est impossible (plus de 3 cartes, plus de
  15 runs par jour, carte inconnue, trop d'ennemis pour la durée, run déjà terminée ou d'un autre joueur).
  Hors ligne ou si la base n'est pas à jour, l'envoi se fait comme avant.
- Sécurité : la commande TRUNCATE (qui échappe au RLS et que Supabase accorde par défaut) est retirée
  sur toutes les tables.
- CI : le schéma de la base est testé à chaque push sur un PostgreSQL vierge (23 vérifications), et le
  build indique si la base Supabase en ligne est à jour.
- **À faire par Clem** : recoller `supabase/schema.sql` dans le SQL Editor de Supabase (rien n'est supprimé).

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
