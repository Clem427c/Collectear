import 'config.dart';

/// Publicités (étape 4, GDD diapo 15) : vidéos récompensées et optionnelles uniquement.
///  - run bonus : quand il ne reste plus aucune run, une vidéo en donne une (3 par jour au plus) ;
///  - résurrection : à la mort, une vidéo permet de repartir avec 1 vie (une fois par run).
/// Jamais de pub imposée pendant une run.
class AdRules {
  AdRules._();

  /// Le bouton « vidéo = +1 run » s'affiche : plus aucune run et limite du jour pas atteinte.
  static bool canWatchForBonusRun({required int runsLeft, required int adRunsToday}) =>
      runsLeft <= 0 && adRunsToday < GameConfig.adBonusRunsPerDay;

  /// Vidéos bonus encore possibles aujourd'hui.
  static int bonusRunsLeft(int adRunsToday) =>
      (GameConfig.adBonusRunsPerDay - adRunsToday).clamp(0, GameConfig.adBonusRunsPerDay);
}

/// Comment les vidéos sont servies sur cet appareil.
enum AdMode {
  /// Vraies vidéos AdMob (Android, consentement RGPD obtenu ou non requis).
  real,

  /// Écran de test de 5 s (web, PC, ou Android sans consentement tant qu'on a les identifiants de test).
  simulated,

  /// Aucune vidéo possible : vrais identifiants mais pas de consentement (refusé ou formulaire en échec).
  unavailable,
}

/// Consentement RGPD (UMP, la plateforme de consentement de Google) : en Europe, AdMob exige
/// que le joueur ait fait son choix avant toute demande de pub. Le formulaire est celui de Google
/// (configuré dans le compte AdMob → Confidentialité et messages), affiché au démarrage s'il le faut,
/// et réouvrable depuis ⚙ Paramètres → Publicités.
class AdConsent {
  AdConsent._();

  /// Choisit le mode des vidéos.
  ///  - [nativeAds] : la plateforme sait afficher des vidéos AdMob (Android aujourd'hui) ;
  ///  - [canRequestAds] : réponse de l'UMP (consentement donné, ou non requis hors d'Europe) ;
  ///  - [testIds] : on utilise encore les identifiants de test de Google.
  ///
  /// PROVISOIRE : sans compte AdMob, aucun message de consentement n'est configuré, donc l'UMP échoue
  /// en Europe. Avec les identifiants de test, on se rabat alors sur la vidéo simulée pour que Clem
  /// puisse tester le parcours ; avec les vrais identifiants, plus aucune vidéo sans consentement.
  static AdMode mode({required bool nativeAds, required bool canRequestAds, required bool testIds}) {
    if (!nativeAds) return AdMode.simulated;
    if (canRequestAds) return AdMode.real;
    return testIds ? AdMode.simulated : AdMode.unavailable;
  }

  /// Texte d'état affiché dans ⚙ Paramètres → Publicités.
  static String statusLabel(AdMode mode, {required bool testIds}) => switch (mode) {
        AdMode.real => testIds ? 'Vidéos de test de Google (aucun revenu).' : 'Vidéos AdMob actives.',
        AdMode.simulated => 'Vidéos simulées (5 s d\'attente) : aucune donnée envoyée à une régie.',
        AdMode.unavailable => 'Pas de vidéo : choix de confidentialité non fait ou refusé. '
            'Tu peux le modifier ci-dessous.',
      };
}

/// Identifiants AdMob.
///
/// PROVISOIRE : tant que Clem n'a pas créé son compte AdMob, ce sont les identifiants de TEST
/// publiés par Google (vidéos « Test Ad », aucun revenu, aucun risque pour le compte).
/// Les vrais seront injectés au build (--dart-define ADMOB_REWARDED_ANDROID, secret GitHub)
/// et l'identifiant d'appli dans le manifeste Android par la CI (secret ADMOB_APP_ID).
class AdIds {
  AdIds._();

  static const testAppAndroid = 'ca-app-pub-3940256099942544~3347511713';
  static const testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';

  static const _rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID');

  /// Bloc d'annonces « vidéo récompensée » (Android). Valeur vide → identifiant de test.
  static String get rewardedAndroid => resolve(_rewardedAndroid, testRewardedAndroid);

  /// Ne garde un identifiant fourni au build que s'il a le bon format (sinon, celui de test).
  static String resolve(String provided, String fallback) {
    final v = provided.trim();
    return RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(v) ? v : fallback;
  }

  static bool get usingTestIds => rewardedAndroid == testRewardedAndroid;
}
