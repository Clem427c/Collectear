/// Logique pure de la synchronisation de la collection avec le serveur (testée sans réseau).
///
/// Un exemplaire est identifié par (id de carte, seed de variante). La synchro est une union :
/// rien n'est jamais supprimé, ni en local ni en ligne.
library;

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
