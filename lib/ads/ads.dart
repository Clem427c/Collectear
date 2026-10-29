import 'package:flutter/widgets.dart';

// Sur le web, AdMob n'existe pas : vidéo simulée. Ailleurs : google_mobile_ads (Android, iOS).
import 'ads_mobile.dart' if (dart.library.js_interop) 'ads_web.dart' as impl;

/// Vidéos récompensées (règles dans core/ads.dart).
class Ads {
  Ads._();

  /// À appeler au démarrage (ne bloque pas : la 1re vidéo se charge en arrière-plan).
  static Future<void> init() => impl.init();

  /// true si les vidéos sont simulées (web, PC) : écran de test de 5 s au lieu d'une vraie pub.
  static bool get simulated => impl.simulated;

  /// Montre une vidéo récompensée. Renvoie true si elle a été regardée jusqu'au bout
  /// (récompense gagnée), false si elle a été fermée avant ou si aucune n'est disponible.
  static Future<bool> showRewarded(BuildContext context) => impl.showRewarded(context);
}
