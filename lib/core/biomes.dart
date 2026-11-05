import 'config.dart';
import 'noise.dart';

/// Biomes du monde (GDD diapo 5 : « bruit pour les biomes » ; diapo 8 : « densité selon le biome »).
///
/// PROVISOIRE (question à Clem) : 3 biomes tirés d'un bruit à grande échelle, indépendant des étages.
/// Ils changent la teinte du sol, le mélange des décors, le nombre d'ennemis et la part de tireurs.
/// Ils ne changent pas (encore) les cartes obtenues : « chaque biome a ses espèces » attend Clem.
enum Biome {
  /// Calme et dégagée : fleurs et hautes herbes, peu d'arbres, un peu moins d'ennemis.
  prairie(
    label: 'Prairie',
    entering: 'Tu entres dans la prairie',
    enemyDensity: 0.8,
    meleeShare: 0.6,
    extraDecor: 0,
    tint: 0x10FFF0A0,
    decorWeights: {
      'prop_fleurs': 2.5,
      'prop_herbes_hautes': 2,
      'prop_buisson': 1.2,
      'prop_arbre_rond': 0.4,
      'prop_arbre_pin': 0.3,
      'prop_arbre_fruits': 1.2,
      'prop_rocher': 0.5,
      'prop_cristaux': 0.4,
    },
  ),

  /// Dense : beaucoup d'arbres et de champignons, plus d'ennemis, surtout au corps à corps.
  foret(
    label: 'Forêt',
    entering: 'Tu entres dans la forêt',
    enemyDensity: 1.25,
    meleeShare: 0.75,
    extraDecor: 2,
    tint: 0x1E0A3A20,
    decorWeights: {
      'prop_arbre_rond': 3,
      'prop_arbre_pin': 3,
      'prop_arbre_fruits': 2,
      'prop_arbre_enneige': 2,
      'prop_champignons': 2,
      'prop_souche': 2,
      'prop_fleurs': 0.5,
      'prop_rochers_petits': 0.5,
      'prop_rocher': 0.6,
    },
  ),

  /// Minérale : rochers et cristaux, ennemis en nombre normal mais surtout des tireurs.
  rocailles(
    label: 'Rocailles',
    entering: 'Tu entres dans les rocailles',
    enemyDensity: 1.0,
    meleeShare: 0.35,
    extraDecor: 1,
    tint: 0x26A08660,
    decorWeights: {
      'prop_rocher': 3,
      'prop_rochers_petits': 3,
      'prop_cristaux': 2.5,
      'prop_arbre_rond': 0.3,
      'prop_arbre_pin': 0.5,
      'prop_arbre_fruits': 0.3,
      'prop_fleurs': 0.4,
      'prop_champignons': 0.5,
      'prop_herbes_hautes': 0.6,
    },
  );

  const Biome({
    required this.label,
    required this.entering,
    required this.enemyDensity,
    required this.meleeShare,
    required this.extraDecor,
    required this.tint,
    required this.decorWeights,
  });

  /// Nom affiché (Guide, message en run).
  final String label;

  /// Message affiché quand le joueur change de biome pendant une run.
  final String entering;

  /// Multiplicateur du nombre d'ennemis d'un chunk (gardiens des lieux non compris).
  final double enemyDensity;

  /// Part d'ennemis au corps à corps (le reste tire à distance).
  final double meleeShare;

  /// Décors en plus par chunk (le plafond [BiomeRules.maxExtraDecor] s'ajoute au maximum de base).
  final int extraDecor;

  /// Voile de couleur posé sur le sol (ARGB), très léger pour garder la lisibilité des étages.
  final int tint;

  /// Multiplicateur du poids de chaque décor (1 si absent). Ne fait jamais apparaître un décor
  /// qui n'existe pas à cet étage : il change seulement le mélange.
  final Map<String, double> decorWeights;

  double decorWeight(String name) => decorWeights[name] ?? 1;
}

/// Carte des biomes d'un monde, entièrement déterminée par la seed de la run.
class BiomeMap {
  BiomeMap(this.seed);

  final int seed;

  /// Taille caractéristique d'une zone de biome, en cases (≈ 5 chunks : on en traverse plusieurs par run).
  static const double scale = 40;

  /// Seuils du bruit : en dessous de [rockBelow] rocailles, au-dessus de [forestAbove] forêt, sinon prairie.
  /// Réglés pour ≈ 30 % rocailles, 35 % prairie, 35 % forêt.
  static const double rockBelow = 0.42;
  static const double forestAbove = 0.563;

  /// Valeur brute du bruit des biomes (0..1) pour une case.
  double noiseAt(int tx, int ty) => fbm(seed ^ 0xB10E, tx / scale, ty / scale, octaves: 2);

  Biome at(int tx, int ty) => fromNoise(noiseAt(tx, ty));

  static Biome fromNoise(double n) {
    if (n < rockBelow) return Biome.rocailles;
    if (n > forestAbove) return Biome.foret;
    return Biome.prairie;
  }

  /// Biome d'un chunk = celui de sa case centrale (densité d'ennemis).
  Biome ofChunk(int cx, int cy) {
    const n = GameConfig.chunkTiles;
    return at(cx * n + n ~/ 2, cy * n + n ~/ 2);
  }
}

/// Règles chiffrées liées aux biomes.
class BiomeRules {
  BiomeRules._();

  /// Décors en plus au maximum, tous biomes confondus (pour les bornes des tests).
  static const int maxExtraDecor = 2;

  /// Nombre d'ennemis d'un chunk après le biome : [base] × densité, la partie décimale tirée au sort
  /// avec [roll] (0..1). Ex. base 2 en forêt (×1,25) → 2, ou 3 une fois sur 2.
  static int enemyCount(int base, Biome biome, double roll) {
    final v = base * biome.enemyDensity;
    final whole = v.floor();
    return whole + (roll < v - whole ? 1 : 0);
  }
}

/// Annonce du biome en run (« Tu entres dans la forêt »), sans clignoter à la frontière :
/// le nouveau biome doit tenir [settle] secondes, et deux annonces sont espacées d'au moins [cooldown] s.
/// Le biome de départ n'est pas annoncé.
class BiomeTracker {
  BiomeTracker({this.settle = 1.2, this.cooldown = 8});

  final double settle;
  final double cooldown;

  /// Biome annoncé (ou de départ).
  Biome? current;
  Biome? _candidate;
  double _held = 0;
  double _sinceAnnounce = double.infinity;

  /// Biomes traversés pendant la run (départ compris), dans l'ordre de découverte.
  final List<Biome> visited = [];

  /// À appeler à chaque image avec le biome sous le joueur. Renvoie le biome à annoncer, ou null.
  /// [canAnnounce] = false (un autre message est affiché) : l'annonce attend.
  Biome? update(Biome here, double dt, {bool canAnnounce = true}) {
    _sinceAnnounce += dt;
    if (current == null) {
      current = here;
      visited.add(here);
      return null;
    }
    if (here == current) {
      _candidate = null;
      _held = 0;
      return null;
    }
    if (here != _candidate) {
      _candidate = here;
      _held = 0;
    }
    _held += dt;
    if (_held < settle || _sinceAnnounce < cooldown || !canAnnounce) return null;
    current = here;
    _candidate = null;
    _held = 0;
    _sinceAnnounce = 0;
    if (!visited.contains(here)) visited.add(here);
    return here;
  }
}
