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
