/// Écran « À propos » : version du jeu et liens utiles (politique de confidentialité, suppression du compte).
/// Logique pure, sans Flutter, testée dans `test/about_test.dart`.
library;

/// Version affichée du jeu. Doit rester égale à la version de `pubspec.yaml` (vérifié par les tests)
/// et au dernier numéro de `CHANGELOG.md`.
const String kGameVersion = '0.26.0';

/// Numéro du build CI (`--dart-define=BUILD_NUMBER=<n° du run>`), vide en local.
const String kBuildNumber = String.fromEnvironment('BUILD_NUMBER');

/// Adresse du jeu web et de ses pages (publiées par la CI sur GitHub Pages).
const String kWebGameUrl = 'https://clem427c.github.io/Collectear/';
const String kPrivacyUrl = '${kWebGameUrl}confidentialite.html';
const String kAccountDeletionUrl = '${kWebGameUrl}suppression-compte.html';

/// « 0.25.0 (build 123) », ou « 0.25.0 » sans numéro de build (build local).
/// Un numéro de build qui n'est pas un entier positif est ignoré.
String versionLabel({String version = kGameVersion, String build = kBuildNumber}) {
  final b = int.tryParse(build.trim());
  if (b == null || b <= 0) return version;
  return '$version (build $b)';
}

/// Un lien de l'écran « À propos ».
class AboutLink {
  const AboutLink(this.title, this.subtitle, this.url);
  final String title;
  final String subtitle;
  final String url;
}

/// Liens affichés dans l'écran « À propos », dans l'ordre.
const List<AboutLink> kAboutLinks = [
  AboutLink('Politique de confidentialité', 'Ce que le jeu enregistre et pourquoi', kPrivacyUrl),
  AboutLink('Supprimer son compte', 'Marche à suivre, depuis le jeu ou sans lui', kAccountDeletionUrl),
  AboutLink('Jouer sur ordinateur', 'La version web du jeu', kWebGameUrl),
];

/// Vrai si [url] est une adresse https bien formée (on n'ouvre jamais autre chose).
bool isSafeLink(String url) {
  final u = Uri.tryParse(url);
  return u != null && u.scheme == 'https' && u.host.isNotEmpty;
}
