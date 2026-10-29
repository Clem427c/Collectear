/// Skins d'explorateur (étape 4) : purement cosmétiques, aucun effet sur le jeu.
///
/// PROVISOIRE (à valider par Clem) :
///  - les skins s'achètent avec les pièces ramassées en run (les gemmes et les achats en euros
///    viendront avec le compte Google Play) ;
///  - un skin recolore la tenue de l'explorateur (teinte posée sur l'image actuelle) ; de vraies
///    tenues dessinées pourront être générées plus tard avec ComfyUI ;
///  - prix : 300 pièces (≈ 8 runs de récolte), 600 pour un rare, 1 200 pour un épique.
class Skin {
  const Skin(this.id, this.name, this.price, this.light, this.dark, {this.tag, this.tintStrength = 0.5});

  final String id;
  final String name;

  /// Prix en pièces (0 = offert d'office).
  final int price;

  /// Couleurs ARGB (clair, foncé) : aperçu en boutique et teinte du personnage en run.
  final int light;
  final int dark;
  final String? tag;

  /// Force de la teinte posée sur l'image (0 = image d'origine, 1 = recoloration complète).
  final double tintStrength;

  bool get isDefault => price == 0;
}

class Skins {
  Skins._();

  static const defaultId = 'explorateur';

  static const all = <Skin>[
    Skin(defaultId, 'Explorateur', 0, 0xFFB79CFF, 0xFF7B5CFF, tintStrength: 0),
    Skin('azur', 'Éclaireur azur', 300, 0xFF4DD6FF, 0xFF1E6BFF, tag: 'Nouveau'),
    Skin('braise', 'Braise', 300, 0xFFFFB627, 0xFFFF4E2A),
    Skin('sylve', 'Sylve', 300, 0xFF7BE07B, 0xFF1E8A4C),
    Skin('corail', 'Corail', 300, 0xFFFF8FA3, 0xFFE84A5F),
    Skin('nuit', 'Nuit étoilée', 600, 0xFF6B5BFF, 0xFF16104A, tag: 'Rare', tintStrength: 0.6),
    Skin('or', 'Or royal', 1200, 0xFFFFF1A8, 0xFFE0A100, tag: 'Épique', tintStrength: 0.6),
  ];

  static Skin byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => all.first);

  /// Pourquoi un achat est impossible (null si on peut acheter).
  static String? whyNotBuy(Skin skin, {required Set<String> owned, required int coins}) {
    if (skin.isDefault || owned.contains(skin.id)) return 'Déjà à toi';
    if (coins < skin.price) return 'Il te manque ${skin.price - coins} pièces';
    return null;
  }
}
