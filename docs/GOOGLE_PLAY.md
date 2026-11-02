# Fiche Google Play – brouillon (PROVISOIRE)

Préparé le 01/11/2026 pour gagner du temps le jour de la publication. Tout est à relire par Clem.
Rien ici ne demande de payer ni de créer de compte : la création du compte développeur Google Play
(frais unique de 25 $) et l'envoi de l'appli sont à faire par Clem.

## Identité
- Nom de l'appli (30 caractères max) : **Collectear** — ou « Collectear : cartes et aventure » (29)
- Identifiant du paquet : `com.clem427c.collectear` (fixé par `flutter create --org com.clem427c` en CI ;
  **définitif** une fois la première version envoyée)
- Catégorie : Jeux → Aventure (alternative : Jeux de cartes)
- Tags suggérés : Collection, Exploration, Action, Hors ligne
- Politique de confidentialité : https://clem427c.github.io/Collectear/confidentialite.html
  (brouillon : `docs/site/confidentialite.html`, adresse de contact à compléter)

## Description courte (80 caractères max)
> Explore un monde infini, bats des créatures et collectionne 300 cartes uniques !

(79 caractères)

## Description complète (4 000 caractères max)
> Pars à l'aventure dans un monde qui change à chaque partie et deviens le plus grand collectionneur !
>
> 🗺️ EXPLORE
> Chaque run dure 2 minutes dans un monde généré au hasard : vallées, prairies, plateaux et sommets
> enneigés. Grimpe d'étage en étage, saute, esquive… et trouve les lieux cachés : coffres, sanctuaires
> gardés, tours à gravir et ruines aux pierres runiques. Aucune carte, aucune boussole : à toi de fouiller.
>
> ⚔️ COMBATS
> Les créatures attaquent au corps à corps ou à distance, mais préviennent avant de frapper. Lis leurs
> attaques, esquive au bon moment, et gagne une carte tous les 10 ennemis vaincus.
>
> 🃏 COLLECTIONNE 300 CARTES
> Créatures mignonnes ou terrifiantes, héros et héroïnes de 5 raretés, de Commune à Légendaire.
> Chaque exemplaire est unique : couleurs, motifs, Shiny, finitions Dorée, Cristal ou Ombre.
> Emmène une carte en compagnon pour profiter de son bonus pendant la run.
>
> 🤝 ÉCHANGE AVEC TES AMIS
> Ajoute tes amis avec leur code, montre ta liste de souhaits, propose des échanges de 1 à 5 cartes
> et compare vos collections dans le classement. Partage tes plus belles trouvailles !
>
> 🎨 PERSONNALISE
> Skins d'explorateur et cadres de cartes à débloquer avec les pièces ramassées en jouant.
>
> Gratuit, avec des vidéos publicitaires facultatives (jamais pendant une partie).

(Les émojis sont autorisés mais facultatifs ; Google déconseille les majuscules à outrance et les
superlatifs du type « meilleur jeu ».)

## Éléments graphiques à fournir
| Élément | Format | Statut |
|---|---|---|
| Icône | 512×512 PNG, 32 bits | à faire (aujourd'hui : icône Flutter par défaut) |
| Image de présentation | 1024×500 JPG/PNG | à faire |
| Captures téléphone | 2 à 8, 16:9 ou 9:16, côté ≥ 320 px | la CI produit déjà des captures web (artefacts) ; à refaire en plein écran téléphone |

Je peux préparer les prompts ComfyUI de l'icône et de l'image de présentation (comme pour les décors).

## Questionnaire « Sécurité des données » (réponses suggérées)
- Données collectées ou partagées : **oui**.
- Chiffrées en transit : **oui** (HTTPS vers Supabase et Google).
- Suppression des données sur demande : **oui** (par e-mail, voir la politique) — il faudra un moyen de
  demander la suppression ; Google exige aussi un lien web de demande de suppression de compte.
- Types de données :
  - Informations personnelles → **Adresse e-mail** : collectée, non partagée, facultative, pour la
    gestion du compte.
  - Informations personnelles → **Identifiants utilisateur** (pseudo, code ami) : collectés, facultatifs,
    pour les fonctionnalités de l'appli.
  - Activité dans l'appli → **Interactions** (runs, cartes, échanges) : collectées, pour les
    fonctionnalités et la prévention des fraudes.
  - Identifiants de l'appareil → **Identifiant publicitaire** : collecté et partagé (AdMob), pour la
    publicité.
  - Infos et performances de l'appli → **Diagnostics** : collectés par le SDK AdMob (à vérifier dans la
    documentation « Sécurité des données » de Google Mobile Ads au moment de remplir).

## Classification du contenu (questionnaire IARC, réponses suggérées)
- Violence : **fantastique, non réaliste** (créatures, coups sans sang) → probablement PEGI 7.
- Pas de sang, pas de langage grossier (pseudos filtrés), pas de jeux d'argent, pas d'achat de coffres
  aléatoires contre de l'argent réel (les cartes ne s'achètent pas).
- Interactions entre utilisateurs : **oui** (échanges entre amis, pseudos visibles) ; pas de chat libre.
- Achats intégrés : non pour l'instant (gemmes prévues plus tard → à mettre à jour ce jour-là).
- Publicités : **oui**.

## Public cible
- Tranche d'âge suggérée : **13 ans et plus** (ou 16+). Viser les moins de 13 ans soumettrait l'appli au
  programme « Familles » (pubs certifiées, règles plus strictes) : à éviter au lancement.

## Avant d'envoyer la première version
- [ ] Compte développeur Google Play (Clem ; les nouveaux comptes personnels doivent faire un test fermé
      avec au moins 12 testeurs pendant 14 jours avant la production).
- [ ] Clé de signature (keystore) générée par Clem, ajoutée en Secrets GitHub (jamais dans le dépôt) ;
      la CI signe alors l'**AAB** `collectear.aab` (voir « Clé d'envoi » ci-dessous). En attendant, elle
      produit à chaque push un `collectear-TEST.aab` signé avec une clé jetable (refusé par Google Play).
- [ ] Vrais identifiants AdMob et message RGPD (voir ROADMAP, Étape 4).
- [x] Nom affiché sur le téléphone : « Collectear » (02/11).
- [ ] Icône : prompts prêts (`docs/prompts_store.csv`, voir « Icône et image de présentation »).
- [ ] Adresse de contact dans la politique de confidentialité.

## Clé d'envoi (keystore) — à faire par Clem, une seule fois
Google Play demande que chaque AAB soit signé avec ta **clé d'envoi**. Avec la « signature d'applications
par Google Play » (proposée par défaut), Google garde la vraie clé ; si tu perds la clé d'envoi, tu peux
demander à Google de la réinitialiser. Garde quand même le fichier `.jks` et son mot de passe en lieu sûr
(gestionnaire de mots de passe), **jamais dans le dépôt**.

1. Sur ton PC (Java est installé avec Android Studio ; sinon `winget install EclipseAdoptium.Temurin.17.JDK`) :
   `keytool -genkeypair -v -keystore collectear-upload.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   (il demande un mot de passe et ton nom ; le reste peut rester vide).
2. Encoder le fichier en texte : PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes("collectear-upload.jks")) | Set-Clipboard`
3. GitHub → dépôt → Settings → Secrets and variables → Actions → New repository secret, 4 secrets :
   - `ANDROID_KEYSTORE_BASE64` : le texte copié à l'étape 2 ;
   - `ANDROID_KEYSTORE_PASSWORD` : le mot de passe ;
   - `ANDROID_KEY_ALIAS` : `upload` ;
   - `ANDROID_KEY_PASSWORD` : le même mot de passe (PKCS12 n'en a qu'un).
4. Au push suivant, la CI produit l'artefact `collectear-aab` → `collectear.aab` (onglet Actions → le run →
   Artifacts), prêt à être envoyé dans la Play Console. Son numéro de version (versionCode) est le numéro
   du run CI, donc toujours croissant.

L'APK de test (lien « dernier APK ») garde sa signature habituelle : pas besoin de le désinstaller.
