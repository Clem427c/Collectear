/// Skins d'explorateur (étape 4) : purement cosmétiques, aucun effet sur le jeu.
///
/// PROVISOIRE (à valider par Clem) :
///  - les skins s'achètent avec les pièces ramassées en run (les gemmes et les achats en euros
///    viendront avec le compte Google Play) ;
///  - un skin change la couleur de la cape de l'explorateur (images recolorées en CI) ; des tenues
///    entièrement dessinées pourront être générées plus tard avec ComfyUI ;
///  - prix : 300 pièces (≈ 8 runs de récolte), 600 pour un rare, 1 200 pour un épique.
class Skin {
  const Skin(this.id, this.name, this.price, this.light, this.dark, {this.tag});

  final String id;
  final String name;

  /// Prix en pièces (0 = offert d'office).
  final int price;

  /// Couleurs ARGB (clair, foncé) de la cape. Les images de l'explorateur à ces couleurs sont
  /// fabriquées en CI par tool/process_decors.py (qui relit ce fichier) : perso_explorateur_face__<id>.png…
  final int light;
  final int dark;
  final String? tag;

  bool get isDefault => price == 0;

  /// Nom de l'image de l'explorateur pour ce skin (pose = face, dos, profil, attaque).
  String sprite(String pose) => isDefault ? 'perso_explorateur_$pose' : 'perso_explorateur_${pose}__$id';
}

class Skins {
  Skins._();

  static const defaultId = 'explorateur';

  static const all = <Skin>[
    Skin(defaultId, 'Explorateur', 0, 0xFFB79CFF, 0xFF7B5CFF),
    Skin('azur', 'Éclaireur azur', 300, 0xFF4DD6FF, 0xFF1E6BFF, tag: 'Nouveau'),
    Skin('braise', 'Braise', 300, 0xFFFFB627, 0xFFFF4E2A),
    Skin('sylve', 'Sylve', 300, 0xFF7BE07B, 0xFF1E8A4C),
    Skin('corail', 'Corail', 300, 0xFFFF8FA3, 0xFFE84A5F),
    Skin('nuit', 'Nuit étoilée', 600, 0xFF9AA3D6, 0xFF101028, tag: 'Rare'),
    Skin('or', 'Or royal', 1200, 0xFFFFE680, 0xFFC27C00, tag: 'Épique'),
  ];

  static Skin byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => all.first);

  /// Pourquoi un achat est impossible (null si on peut acheter).
  static String? whyNotBuy(Skin skin, {required Set<String> owned, required int coins}) {
    if (skin.isDefault || owned.contains(skin.id)) return 'Déjà à toi';
    if (coins < skin.price) return 'Il te manque ${skin.price - coins} pièces';
    return null;
  }
}

/// Cadres de cartes (étape 4) : purement cosmétiques, ils entourent les cartes de SA collection
/// (bestiaire, compagnon, récapitulatif). Les cartes des amis gardent leur bord blanc.
///
/// PROVISOIRE (à valider par Clem) : payés en pièces comme les skins (250 ; 500 pour un rare ;
/// 1 000 pour un épique). Le cadre d'une finition (Dorée, Cristal, Ombre, Shiny) reste dessiné
/// par-dessus l'illustration : le cadre acheté ne remplace que le bord de la carte.
class CardFrame {
  const CardFrame(this.id, this.name, this.price, this.colors, {this.tag, this.sweep = false});

  final String id;
  final String name;

  /// Prix en pièces (0 = cadre d'origine, offert).
  final int price;

  /// Couleurs ARGB du dégradé du cadre (vide pour le cadre d'origine).
  final List<int> colors;
  final String? tag;

  /// Dégradé circulaire (reflets tout autour, pour les cadres irisés) au lieu d'un dégradé en biais.
  final bool sweep;

  bool get isDefault => price == 0;
}

class CardFrames {
  CardFrames._();

  static const defaultId = 'classique';

  static const all = <CardFrame>[
    CardFrame(defaultId, 'Classique', 0, []),
    CardFrame('givre', 'Cadre givré', 250, [0xFFFFFFFF, 0xFFBFEFFF, 0xFF4DB8FF]),
    CardFrame('lave', 'Cadre de lave', 250, [0xFFFFE08A, 0xFFFF7A1A, 0xFFB3200F]),
    CardFrame('sylve', 'Cadre de lierre', 250, [0xFFD8FF9E, 0xFF5CCB5F, 0xFF1F6B3A]),
    CardFrame('holo', 'Cadre holographique', 500,
        [0xFFFF8FF5, 0xFF6BE3FF, 0xFFB6FF8F, 0xFFFFE680, 0xFFFF8FF5],
        tag: 'Rare', sweep: true),
    CardFrame('royal', 'Cadre royal', 1000, [0xFFFFF4B0, 0xFFFFC233, 0xFF9C5A00, 0xFFFFE680],
        tag: 'Épique'),
  ];

  static CardFrame byId(String? id) => all.firstWhere((f) => f.id == id, orElse: () => all.first);

  /// Pourquoi un achat est impossible (null si on peut acheter).
  static String? whyNotBuy(CardFrame frame, {required Set<String> owned, required int coins}) {
    if (frame.isDefault || owned.contains(frame.id)) return 'Déjà à toi';
    if (coins < frame.price) return 'Il te manque ${frame.price - coins} pièces';
    return null;
  }
}
