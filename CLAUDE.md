# Collectear – consignes pour Claude

Jeu mobile Flutter + Flame développé par Claude pour Clem (game designer, ancien dev web).
Langue du projet : **français** (code commenté en français, messages de commit en français).

## Où trouver quoi
- `docs/` : GDD (pptx) et classeur des 300 cartes (xlsx). Source de vérité du design.
- `ROADMAP.md` : feuille de route et **prochaine tâche à faire**. Le lire en premier à chaque session.
- `CHANGELOG.md` : ce qui a été livré, session par session. Le compléter à chaque session.
- `assets/data/cards.json` : les 300 cartes (exportées du xlsx ; regénérer si le xlsx change).
- `lib/core/` : logique pure Dart, testée (`test/`). Pas de dépendance à Flame ici.
- `lib/game/` : moteur Flame (monde, joueur, ennemis, spawner).
- `lib/ui/` : écrans Flutter (menu, run, récap, bestiaire).

## Contraintes d'environnement
- Le conteneur de Claude **ne peut pas** installer Flutter (storage.googleapis.com et pub.dev bloqués).
  Toute compilation/test passe par **GitHub Actions** (`.github/workflows/ci.yml`).
- Les dossiers `android/` et `web/` sont générés en CI par `flutter create` (ignorés par git)
  tant qu'ils n'ont pas besoin d'être personnalisés.
- Suivre la CI : `gh api repos/Clem427c/Collectear/actions/runs?per_page=5`.
- Après chaque push sur `main` : web sur https://clem427c.github.io/Collectear/ et APK sur
  https://github.com/Clem427c/Collectear/releases/latest/download/collectear.apk

## Règles de travail
- Petits commits sur `main`, CI verte avant de passer à la tâche suivante.
- Ajouter des tests pour toute logique de `lib/core/`.
- Les règles chiffrées du gameplay sont dans `lib/core/config.dart` (une seule source).
- Ne jamais committer de secrets (clés Supabase, keystore) : utiliser les Secrets GitHub.
- Supabase : secrets GitHub `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` (clé publique `sb_publishable_…`,
  ou ancienne clé `anon` en `eyJ…`). À injecter au build via `--dart-define`. Activer le RLS sur toutes les tables.
- Décisions de design non tranchées : implémenter une version provisoire, la marquer `PROVISOIRE`
  dans le code et la lister dans ROADMAP.md (section « Questions pour Clem »).
