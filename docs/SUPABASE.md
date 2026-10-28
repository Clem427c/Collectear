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

Avec l'e-mail par défaut (« Your sign-in link »), il faut ouvrir l'e-mail **sur l'appareil qui l'a
demandé** et toucher « Sign in ». Pour se connecter depuis n'importe quel appareil, voir le §3 (code).

## 3. Recevoir un CODE dans l'e-mail (recommandé, ~10 min)
Le lien « Sign in » de l'e-mail ne connecte **que l'appareil qui a demandé l'e-mail** (sécurité de
Supabase) : demandé sur PC, ouvert sur le téléphone, il ne connecte pas le PC. Un code à 6 chiffres,
lui, se recopie sur n'importe quel appareil. L'appli a déjà la case pour saisir le code ; il faut juste
que l'e-mail le contienne. Supabase n'autorise à modifier l'e-mail qu'avec un serveur d'envoi
personnel (SMTP). Le plus simple : ton Gmail (gratuit, ~500 e-mails par jour).

**a. Mot de passe d'application Gmail** (ce n'est pas ton vrai mot de passe, il ne sert qu'à l'envoi)
1. https://myaccount.google.com → **Sécurité** → active la **Validation en deux étapes** si ce n'est pas fait.
2. Cherche « **Mots de passe des applications** » (barre de recherche du compte Google), crée-en un
   nommé « Supabase » → Google affiche 16 lettres : copie-les (à ne mettre nulle part ailleurs).

**b. Supabase → envoi par ton Gmail** : menu **Authentication** → **Emails** → onglet **SMTP Settings**
(selon la version : Project Settings → Authentication → SMTP) → **Enable custom SMTP** :
- Sender email : ton adresse Gmail · Sender name : `Collectear`
- Host : `smtp.gmail.com` · Port : `587`
- Username : ton adresse Gmail · Password : les 16 lettres du mot de passe d'application
- **Save**.

**c. Modèles d'e-mail** : même menu **Emails** → onglet **Templates**. Dans **Magic Link** ET dans
**Confirm signup** (le 1er e-mail d'un nouveau compte utilise ce modèle), remplace le contenu par :

```html
<h2>Ton code Collectear</h2>
<p>Saisis ce code dans le jeu :</p>
<p style="font-size:32px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>Ou, sur l'appareil où tu as demandé la connexion : <a href="{{ .ConfirmationURL }}">me connecter</a></p>
```
Sujet conseillé : `Ton code Collectear`. **Save** pour chaque modèle.

**d. Tester** : web → ⚙ → Compte → ton adresse → **Recevoir un code** → recopie le code de l'e-mail
(même s'il est lu sur le téléphone) → **Valider**.

Bonus : avec ton SMTP, la limite de Supabase (2 ou 3 e-mails par heure) disparaît (réglable dans
Authentication → Rate Limits).

## Limites à connaître
- Sans le §3, l'envoi d'e-mails intégré de Supabase est limité (quelques e-mails par heure). Pour le
  lancement public, un service d'envoi dédié (Brevo, Resend…) sera plus adapté que Gmail.
- Si un e-mail n'arrive pas : regarder les indésirables, puis **Authentication → Users** pour voir
  si le compte a été créé.

## Tester
1. Ouvrir le jeu : la fenêtre de connexion s'affiche au premier lancement (ensuite : roue crantée ⚙ → Compte).
2. Saisir son adresse → **Recevoir un code** → ouvrir l'e-mail sur le même appareil et toucher « Sign in ».
3. Paramètres → Compte affiche « Collection sauvegardée en ligne (N exemplaires) » et un code ami en ligne.
4. Se connecter avec la même adresse sur un autre appareil (APK ↔ web) : les cartes s'y ajoutent.
