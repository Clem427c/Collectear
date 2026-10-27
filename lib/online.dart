import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/online_config.dart';

/// Connexion au serveur en ligne (Supabase). Tout est facultatif : sans configuration,
/// ou si le serveur ne répond pas, le jeu fonctionne hors ligne avec la collection locale.
class Online {
  Online._();

  static const OnlineConfig config = OnlineConfig.fromEnvironment;
  static bool _initialized = false;

  /// Vrai si le client Supabase est prêt (secrets présents et valides au build).
  static bool get ready => _initialized;

  static Future<void> init() async {
    if (!config.isUsable || _initialized) return;
    try {
      await Supabase.initialize(url: config.cleanUrl, anonKey: config.cleanKey);
      _initialized = true;
    } catch (e) {
      debugPrint('Supabase indisponible : $e');
    }
  }

  /// Vérifie que le serveur répond et accepte la clé publique (service d'authentification).
  static Future<bool> ping() async {
    if (!config.isUsable) return false;
    try {
      final res = await http
          .get(Uri.parse('${config.cleanUrl}/auth/v1/health'), headers: {'apikey': config.cleanKey})
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
