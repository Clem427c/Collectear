# Mise en place du serveur en ligne (Supabase) – à faire une fois par Clem

Environ 5 minutes, tout se passe dans le tableau de bord Supabase (https://supabase.com/dashboard),
dans le projet Collectear. Aucune clé n'est à copier nulle part : les secrets GitHub sont déjà en place.

## 1. Créer les tables (obligatoire)
1. Menu de gauche **SQL Editor** → **New query**.
2. Copier tout le contenu de [`supabase/schema.sql`](../supabase/schema.sql) et le coller.
3. Cliquer **Run**. Résultat attendu : « Success. No rows returned ».
   (Le script peut être relancé sans risque, il ne supprime rien.)
4. Vérification : menu **Table Editor** → les tables `profiles`, `owned_cards` et `runs` apparaissent
   avec la mention « RLS enabled ».

### Mise à jour du schéma
Quand le jeu évolue (par exemple la 0.10 qui ajoute les runs vérifiées par le serveur), il suffit de
recoller **tout** `supabase/schema.sql` et de cliquer **Run** : rien n'est supprimé.
La CI indique à chaque build si la base est à jour (étape « Base Supabase installée ? »).

## 2. Adresses de retour du lien de connexion (obligatoire)
Menu **Authentication** → **URL Configuration** :
- **Site URL** : `https://clem427c.github.io/Collectear/`
- **Redirect URLs** → **Add URL**, deux fois :
  - `https://clem427c.github.io/Collectear/**` (version web)
  - `com.clem427c.collectear://login-callback` (APK : le lien ouvre directement l'appli)
- **Save**.

Rien à changer dans les modèles d'e-mail : l'e-mail par défaut (« Your sign-in link ») suffit.
Sur téléphone, ouvrir l'e-mail **sur le téléphone où l'APK est installé** et toucher « Sign in ».
(Modifier les modèles, par exemple pour ajouter un code à 6 chiffres, demande un SMTP personnel :
ce sera à faire avant le lancement, voir plus bas.)

## Limites à connaître
- L'envoi d'e-mails intégré de Supabase est limité (quelques e-mails par heure) : suffisant pour tester,
  pas pour le lancement. Avant la publication, il faudra brancher un service d'envoi (SMTP) — on en reparlera.
- Si un e-mail n'arrive pas : regarder les indésirables, puis **Authentication → Users** pour voir
  si le compte a été créé.

## Tester
1. Ouvrir le jeu : la fenêtre de connexion s'affiche au premier lancement (ensuite : roue crantée ⚙ → Compte).
2. Saisir son adresse → **Recevoir un code** → ouvrir l'e-mail sur le même appareil et toucher « Sign in ».
3. Paramètres → Compte affiche « Collection sauvegardée en ligne (N exemplaires) » et un code ami en ligne.
4. Se connecter avec la même adresse sur un autre appareil (APK ↔ web) : les cartes s'y ajoutent.
