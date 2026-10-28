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
- [x] Retours de playtest du 27/10 : cartes plus rares (coffres simples 18 → 6 %), 2 ennemis autour de
  chaque pierre runique, lieux à défi plus fréquents, attaque qui passe d'un étage à l'étage voisin
- [x] Pièces à ramasser (sol, ennemis, lieux) et énergies achetables en Boutique (5 par jour au plus) (P)
- [x] Retours du 27/10 (soir) : carte gagnée qui file dans un coin, badge Nouveau dans le coin de la carte,
  guide des lieux (bouton ?), roue crantée (son, vibrations, compte), connexion au premier lancement,
  optimisation (sons réutilisés, sol mis en cache, ennemis hors écran figés)
- [ ] Nouveaux retours de playtest → réglages (vitesses, densité d'ennemis, zoom, prix des énergies)
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
- [x] Détourage : fond blanc enfermé dans le dessin retiré (358 poches vérifiées), dessin entièrement dans le rond
- [x] Prompts ComfyUI des sols, décors, lieux, pièces, personnage jouable et ennemis (`docs/prompts_decors.csv`)
- [x] Décors générés par Clem (41 images) et intégrés : sols par étage, décors, lieux, pièces, perso, ennemis (27/10)
- [x] Chrono d'alerte des 15 dernières secondes ; gardiens de sanctuaire au même étage, tenus en laisse, en élite
- [ ] Décors : collisions avec les arbres et rochers ? (aujourd'hui on passe à travers)

## Étape 3 – En ligne (Supabase) — en cours
Clem a créé le projet Supabase et ajouté les secrets GitHub `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` (26/10).
- [x] Secrets vérifiés en CI sans les afficher (présents, URL https, clé publishable) et injectés au build (27/10)
- [x] `supabase_flutter` branché : client initialisé au démarrage, état du serveur dans le Profil
- [x] Schéma SQL (profils avec code ami, collection) avec RLS dans `supabase/schema.sql`, testé sur PostgreSQL (27/10)
- [x] Connexion e-mail sans mot de passe (code à 6 chiffres, ou lien magique sur le web) dans le Profil (27/10)
- [x] Synchro de la collection (union, rien n'est supprimé) au démarrage, à la connexion et en fin de run (27/10)
- [x] APK : le lien de l'e-mail ouvre l'appli (Supabase n'autorise plus à modifier les modèles d'e-mail sans SMTP)
- [x] **Clem** : SQL collé (tables `profiles` et `owned_cards` présentes, vérifié par la CI le 28/10)
- [x] Pseudo modifiable (toucher le nom dans le Profil), enregistré en ligne (28/10)
- [x] Stats du profil en ligne (fonction `my_stats`, fusionnées avec celles de l'appareil) (28/10)
- [x] Anti-triche, 1re partie : runs ouvertes/fermées par le serveur (`start_run`/`finish_run`) qui ajoute
  lui-même les cartes ; 15 runs/jour, 3 cartes/run, ennemis plausibles ; schéma testé en CI sur PostgreSQL (28/10)
- [ ] **Clem** : recoller `supabase/schema.sql` (mise à jour 0.10 : table `runs` absente au 28/10) — la CI dit si la base est à jour
- [ ] **Clem** : vérifier les adresses de retour (`docs/SUPABASE.md` §2), invérifiables depuis la CI
- [ ] Anti-triche, 2e partie : fermer l'ajout direct de cartes (attend la réponse de Clem sur les cartes
  gagnées hors ligne), puis tirage des cartes par le serveur (rareté contrôlée)
- [x] Amis : ajout par code ami, demandes (accepter/refuser/annuler), retrait (28/10)
- [x] Échanges carte contre carte entre amis : proposer, accepter (atomique côté serveur), refuser,
  annuler, historique ; la carte donnée quitte l'appareil et ne peut pas être renvoyée par la synchro (28/10)
- [x] Classement entre amis (cartes différentes, exemplaires, record d'ennemis) (28/10)
- [ ] Connexion Google (attend la réponse de Clem, voir « Questions »)
- [ ] Profil d'un ami (voir sa collection en détail) ; notifications d'échange (push) — plus tard
- [ ] **Prochaine session** : traiter les réponses de Clem (hors ligne, pseudos, collisions, énergies) ;
  sinon la pub (étape 4, demande un compte AdMob créé par Clem)

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

### Pièces et énergies (27/10)
- PROVISOIRE : une run rapporte ≈ 30 à 50 pièces (≈ 2 au sol par chunk, +2 par ennemi, +10 par lieu).
  Énergie = 60 pièces, puis +40 à chaque achat du jour (60, 100, 140, 180, 220), 5 par jour au plus, et
  seulement quand les runs gratuites sont épuisées (une énergie ne se garde pas). Ça te va ?
- Les pièces restent sur l'appareil pour l'instant (pas encore sauvegardées en ligne).

### Décors (27/10)
- Intégrés. PROVISOIRE : arbres, rochers et buissons sont décoratifs (on passe à travers). Veux-tu
  qu'ils bloquent le passage (plus de stratégie, mais risque de se coincer) ?
- Une image ne te plaît pas ? `py tool\comfy_batch.py --decors --redo N` (N = colonne « numero »).

### En ligne
- Pour la connexion Google, il faudra créer des identifiants OAuth dans Google Cloud et les coller dans
  Supabase (Authentication → Providers → Google). Je commencerai par l'e-mail (aucun réglage). Tu valides ?
- Le compte est maintenant dans la roue crantée ⚙ → Compte (et proposé au premier lancement).
- **À faire (5 min)** : les 2 réglages de `docs/SUPABASE.md` (coller le SQL, ajouter les 2 adresses de retour).
  Plus besoin de toucher aux modèles d'e-mail.
- PROVISOIRE : la collection locale appartient à l'appareil. Si un 2e compte se connecte sur le même
  téléphone, les cartes locales partent aussi sur ce compte. Préfères-tu qu'à la déconnexion on vide
  la collection locale (elle reviendra à la reconnexion) ?
- Anti-triche (28/10) : les runs jouées connecté sont maintenant ouvertes et fermées par le serveur, qui
  ajoute lui-même les cartes (3 au plus, 15 runs par jour au plus). PROVISOIRE : l'appli peut encore
  ajouter des cartes directement (cartes gagnées hors ligne, collection d'avant la connexion), donc une
  appli modifiée pourrait toujours tricher. **Question** : les cartes gagnées **hors ligne** doivent-elles
  compter en ligne ? (a) oui, comme aujourd'hui (pratique mais trichable) ; (b) non : sans connexion, la
  run se joue mais ses cartes restent sur l'appareil ; (c) on exige la connexion pour lancer une run.
  Je recommande (b) : c'est la seule option qui rend les échanges entre joueurs sûrs.
- PROVISOIRE : le jour des 15 runs est compté en heure de Paris côté serveur (l'appli compte en heure
  du téléphone). Les énergies ne sont pas encore vérifiées par le serveur (les pièces sont sur l'appareil).
- Échanges (28/10) : un exemplaire contre un exemplaire, uniquement entre amis. PROVISOIRE :
  20 propositions en attente au plus, 200 amis au plus, pas d'expiration automatique des propositions
  (seulement quand une des cartes change de main). Veux-tu des échanges à plusieurs cartes (2 contre 1…) ?
  Faut-il pouvoir échanger sa dernière carte d'une espèce (aujourd'hui oui) ?
- Classement entre amis : trié par nombre de cartes différentes. Autre critère préféré (rareté, points) ?
- Pseudo : 2 à 24 caractères, lettres (accents compris), chiffres, espaces, - ' . _ — pas d'émojis.
  Pas encore de filtre des gros mots ni d'unicité : à prévoir avant les amis/classements ? 

### Illustrations (suite)
Remarque : les 4 bûcherons (035 Hugo, 065 Pio, 070 Milo, 079 Anatole) se ressemblent beaucoup
(barbe rousse, chemise à carreaux, hache). Faut-il en différencier certains (âge, coiffure, couleurs) ?
