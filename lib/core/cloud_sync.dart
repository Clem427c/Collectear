/// Logique pure de la synchronisation de la collection avec le serveur (testée sans réseau).
///
/// Un exemplaire est identifié par (id de carte, seed de variante). La synchro est une union :
/// rien n'est jamais supprimé, ni en local ni en ligne.
library;

import 'moderation.dart';

/// Ce qu'il faut faire pour que la collection locale et la collection en ligne soient identiques.
class SyncPlan {
  const SyncPlan({required this.toUpload, required this.toAddLocally});

  /// Exemplaires présents sur cet appareil mais pas encore en ligne.
  final List<(int, int)> toUpload;

  /// Exemplaires présents en ligne (gagnés sur un autre appareil) mais pas sur cet appareil.
  final List<(int, int)> toAddLocally;

  bool get isEmpty => toUpload.isEmpty && toAddLocally.isEmpty;
}

/// Compare la collection locale (id → seeds) et les exemplaires en ligne.
/// Les doublons exacts (même carte, même seed) ne comptent qu'une fois, comme côté serveur
/// (contrainte d'unicité user_id + card_id + seed).
SyncPlan planSync(Map<int, List<int>> local, Iterable<(int, int)> remote) {
  final localSet = <(int, int)>{
    for (final e in local.entries)
      for (final seed in e.value) (e.key, seed),
  };
  final remoteSet = remote.toSet();
  int byCard((int, int) a, (int, int) b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);
  return SyncPlan(
    toUpload: localSet.difference(remoteSet).toList()..sort(byCard),
    toAddLocally: remoteSet.difference(localSet).toList()..sort(byCard),
  );
}

/// Lignes à envoyer à la table `owned_cards` (voir supabase/schema.sql).
List<Map<String, Object>> toRows(String userId, Iterable<(int, int)> items) => [
      for (final (id, seed) in items) {'user_id': userId, 'card_id': id, 'seed': seed},
    ];

/// Lit les lignes renvoyées par le serveur ; ignore celles qui sont mal formées.
List<(int, int)> fromRows(Iterable<Map<String, dynamic>> rows) {
  final out = <(int, int)>[];
  for (final r in rows) {
    final id = r['card_id'];
    final seed = r['seed'];
    if (id is int && seed is int) out.add((id, seed));
  }
  return out;
}

/// Découpe une liste en paquets (envois au serveur par lots).
List<List<T>> chunked<T>(List<T> items, int size) => [
      for (var i = 0; i < items.length; i += size)
        items.sublist(i, i + size > items.length ? items.length : i + size),
    ];

/// Adresse e-mail plausible (vérification légère avant d'appeler le serveur).
bool isPlausibleEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(s.trim());

/// Code reçu par e-mail : 6 chiffres par défaut chez Supabase (configurable jusqu'à 10).
bool isPlausibleOtp(String s) => RegExp(r'^\d{6,10}$').hasMatch(s.replaceAll(' ', ''));

/// Message en français pour une erreur de connexion renvoyée par Supabase.
/// Deux limites différentes existent :
/// - par adresse : un nouvel e-mail au plus toutes les 60 s (« For security purposes… after N seconds ») ;
/// - pour tout le projet : quelques e-mails par HEURE avec l'envoi intégré de Supabase
///   (« email rate limit exceeded ») — relevée en branchant un SMTP personnel.
String authErrorMessage(String message, {String? code}) {
  final m = message.toLowerCase();
  if (code == 'over_email_send_rate_limit' || m.contains('email rate limit')) {
    return 'Limite d\'e-mails du serveur atteinte (quelques-uns par heure pendant les tests). '
        'Réessaie dans une heure.';
  }
  final wait = RegExp(r'after (\d+) seconds?').firstMatch(m);
  if (wait != null) return 'Un e-mail vient d\'être envoyé : réessaie dans ${wait.group(1)} s.';
  if (code == 'over_request_rate_limit' || m.contains('rate limit')) {
    return 'Trop de demandes : réessaie dans quelques minutes.';
  }
  if (code == 'otp_expired' || m.contains('expired') || m.contains('invalid')) {
    return 'Code ou lien invalide ou expiré : redemande un e-mail.';
  }
  return message;
}

// --- Profil en ligne : pseudo et statistiques ---

/// Pseudo par défaut (même valeur que la colonne profiles.display_name du serveur).
const String defaultPseudo = 'Explorateur';

/// Longueur maximale d'un pseudo (contrainte du serveur : 1 à 24 caractères).
const int maxPseudoLength = 24;

/// Pseudo nettoyé : espaces en trop retirés au début, à la fin et entre les mots.
String normalizePseudo(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Message d'erreur si le pseudo (déjà nettoyé) n'est pas accepté, sinon null.
/// Lettres (accents compris), chiffres, espaces, tiret, apostrophe, point et souligné.
String? pseudoError(String pseudo) {
  final p = normalizePseudo(pseudo);
  if (p.isEmpty) return 'Choisis un pseudo.';
  if (p.runes.length < 2) return 'Au moins 2 caractères.';
  if (p.runes.length > maxPseudoLength) return 'Au plus $maxPseudoLength caractères.';
  if (!RegExp(r"^[\p{L}\p{N} '’._-]+$", unicode: true).hasMatch(p)) {
    return 'Lettres, chiffres, espaces et - \' . _ seulement.';
  }
  // PROVISOIRE : filtre côté appli seulement (voir moderation.dart).
  if (containsProfanity(p)) return 'Ce pseudo n\'est pas autorisé. Choisis-en un autre.';
  return null;
}

/// Erreur pour un pseudo CHOISI par le joueur : en plus des règles de [pseudoError], le pseudo par
/// défaut « Explorateur » est refusé (tout le monde l'a, on ne distinguerait pas ses amis).
String? chosenPseudoError(String pseudo) {
  final err = pseudoError(pseudo);
  if (err != null) return err;
  if (normalizePseudo(pseudo).toLowerCase() == defaultPseudo.toLowerCase()) {
    return 'Choisis un pseudo à toi : « $defaultPseudo » est celui de tout le monde.';
  }
  return null;
}

/// Faut-il demander au joueur de choisir son pseudo ? Oui une fois connecté, son profil en ligne lu,
/// s'il n'a toujours que le pseudo par défaut.
bool needsPseudoChoice({required bool signedIn, required bool profileLoaded, required String pseudo}) =>
    signedIn && profileLoaded && normalizePseudo(pseudo) == defaultPseudo;

/// Quel pseudo garder quand on retrouve son profil en ligne ?
/// Le pseudo choisi (différent de celui par défaut) l'emporte ; si les deux ont été choisis,
/// c'est celui du serveur (il a pu être changé sur un autre appareil).
/// Renvoie (pseudo à garder, faut-il l'envoyer au serveur).
(String, bool) reconcilePseudo({required String local, required String? remote}) {
  final r = remote == null ? defaultPseudo : normalizePseudo(remote);
  final l = normalizePseudo(local);
  if (r != defaultPseudo && r.isNotEmpty) return (r, false);
  if (l != defaultPseudo && pseudoError(l) == null) return (l, true);
  return (defaultPseudo, false);
}

/// Statistiques du profil d'explorateur.
class ProfileStats {
  const ProfileStats({this.runs = 0, this.kills = 0, this.cards = 0, this.bestKills = 0});

  final int runs;
  final int kills;
  final int cards;
  final int bestKills;

  /// Lit la ligne renvoyée par la fonction serveur my_stats() (liste d'une ligne ou ligne seule).
  static ProfileStats? fromRpc(Object? data) {
    final row = data is List ? (data.isEmpty ? null : data.first) : data;
    if (row is! Map) return null;
    int n(String k) => switch (row[k]) { final int v => v, final num v => v.toInt(), final String v => int.tryParse(v) ?? 0, _ => 0 };
    return ProfileStats(runs: n('runs'), kills: n('kills'), cards: n('cards'), bestKills: n('best_kills'));
  }

  /// Fusion appareil + serveur. Le serveur ne compte que les runs jouées connecté (depuis la
  /// version 0.10), l'appareil que celles jouées sur lui : on garde le plus grand de chaque.
  // PROVISOIRE : quand toutes les runs passeront par le serveur, ses chiffres feront foi.
  ProfileStats merge(ProfileStats? other) => other == null
      ? this
      : ProfileStats(
          runs: runs > other.runs ? runs : other.runs,
          kills: kills > other.kills ? kills : other.kills,
          cards: cards > other.cards ? cards : other.cards,
          bestKills: bestKills > other.bestKills ? bestKills : other.bestKills,
        );
}

/// Cartes d'une run au format attendu par la fonction serveur finish_run().
List<Map<String, int>> runCardsPayload(Iterable<(int, int)> items) => [
      for (final (id, seed) in items) {'card_id': id, 'seed': seed},
    ];
