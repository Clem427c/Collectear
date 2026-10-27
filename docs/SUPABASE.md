# Mise en place du serveur en ligne (Supabase) – à faire une fois par Clem

Environ 5 minutes, tout se passe dans le tableau de bord Supabase (https://supabase.com/dashboard),
dans le projet Collectear. Aucune clé n'est à copier nulle part : les secrets GitHub sont déjà en place.

## 1. Créer les tables (obligatoire)
1. Menu de gauche **SQL Editor** → **New query**.
2. Copier tout le contenu de [`supabase/schema.sql`](../supabase/schema.sql) et le coller.
3. Cliquer **Run**. Résultat attendu : « Success. No rows returned ».
   (Le script peut être relancé sans risque, il ne supprime rien.)
4. Vérification : menu **Table Editor** → les tables `profiles` et `owned_cards` apparaissent
   avec la mention « RLS enabled ».

## 2. Adresse du jeu pour le lien de connexion (obligatoire pour le web)
Menu **Authentication** → **URL Configuration** :
- **Site URL** : `https://clem427c.github.io/Collectear/`
- **Redirect URLs** → **Add URL** : `https://clem427c.github.io/Collectear/**`
- **Save**.

## 3. Code à 6 chiffres dans l'e-mail (obligatoire pour l'APK)
Sur téléphone, l'appli ne peut pas recevoir le lien magique : on saisit le code reçu par e-mail.
Menu **Authentication** → **Emails** (ou *Email Templates*) :
- Modèle **Magic Link** : ajouter dans le corps la ligne
  `<p>Ton code Collectear : <strong>{{ .Token }}</strong></p>`
- Modèle **Confirm signup** : ajouter la même ligne (c'est l'e-mail reçu à la toute première connexion).
- **Save** pour chacun.

## Limites à connaître
- L'envoi d'e-mails intégré de Supabase est limité (quelques e-mails par heure) : suffisant pour tester,
  pas pour le lancement. Avant la publication, il faudra brancher un service d'envoi (SMTP) — on en reparlera.
- Si un e-mail n'arrive pas : regarder les indésirables, puis **Authentication → Users** pour voir
  si le compte a été créé.

## Tester
1. Ouvrir le jeu → onglet **Profil** → « Compte en ligne ».
2. Saisir son adresse → **Recevoir un code** → saisir le code (ou, sur ordinateur, cliquer le lien).
3. Le Profil affiche « Collection sauvegardée en ligne (N exemplaires) » et un code ami en ligne.
4. Se connecter avec la même adresse sur un autre appareil (APK ↔ web) : les cartes s'y ajoutent.
