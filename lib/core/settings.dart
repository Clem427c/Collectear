import 'package:shared_preferences/shared_preferences.dart';

/// Réglages du joueur (roue crantée), enregistrés sur l'appareil.
class Settings {
  Settings._(this._prefs);

  static const _kVolume = 'set_volume';
  static const _kHaptics = 'set_haptics';
  static const _kLoginPrompt = 'set_login_prompt_shown';

  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  /// Volume des effets sonores, de 0 (muet) à 1.
  double get volume => (_prefs.getDouble(_kVolume) ?? 0.8).clamp(0.0, 1.0);
  Future<void> setVolume(double v) => _prefs.setDouble(_kVolume, v.clamp(0.0, 1.0));

  bool get haptics => _prefs.getBool(_kHaptics) ?? true;
  Future<void> setHaptics(bool v) => _prefs.setBool(_kHaptics, v);

  /// La fenêtre « Connecte-toi » du premier lancement a-t-elle déjà été proposée ?
  bool get loginPromptShown => _prefs.getBool(_kLoginPrompt) ?? false;
  Future<void> markLoginPromptShown() => _prefs.setBool(_kLoginPrompt, true);
}
