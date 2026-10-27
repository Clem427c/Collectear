import 'dart:convert';

/// Configuration du serveur en ligne (Supabase).
///
/// L'URL et la clé publique sont injectées au build par la CI :
///   flutter build web --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…
/// (secrets GitHub du même nom). La clé « publishable » est faite pour être embarquée dans l'app :
/// la sécurité repose sur le RLS activé sur toutes les tables.
enum OnlineConfigStatus { absent, invalidUrl, invalidKey, ok }

extension OnlineConfigStatusInfo on OnlineConfigStatus {
  String get label => const [
        'Mode hors ligne (serveur non configuré)',
        'Adresse du serveur invalide',
        'Clé du serveur invalide',
        'Serveur configuré',
      ][index];
}

class OnlineConfig {
  const OnlineConfig(this.url, this.key);

  /// Valeurs injectées au build (vides en local ou si les secrets manquent).
  static const OnlineConfig fromEnvironment = OnlineConfig(
    String.fromEnvironment('SUPABASE_URL'),
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String url;
  final String key;

  /// URL sans espaces ni « / » final (un copier-coller depuis le tableau de bord en ajoute parfois).
  String get cleanUrl {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  String get cleanKey => key.trim();

  OnlineConfigStatus get status {
    if (url.trim().isEmpty && key.trim().isEmpty) return OnlineConfigStatus.absent;
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return OnlineConfigStatus.invalidUrl;
    if (!isValidKey(cleanKey)) return OnlineConfigStatus.invalidKey;
    return OnlineConfigStatus.ok;
  }

  bool get isUsable => status == OnlineConfigStatus.ok;

  /// Clé publique : nouveau format `sb_publishable_…` ou ancienne clé `anon` (JWT en `eyJ…`).
  /// Une clé secrète (`sb_secret_…` ou JWT `service_role`) est refusée : elle ne doit jamais être
  /// embarquée dans l'app.
  static bool isValidKey(String k) {
    if (k.startsWith('sb_secret_')) return false;
    if (k.startsWith('sb_publishable_')) return k.length > 'sb_publishable_'.length + 8;
    final parts = k.split('.');
    if (!k.startsWith('eyJ') || parts.length != 3) return false;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}
