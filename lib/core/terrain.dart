import 'config.dart';
import 'noise.dart';

/// Terrain infini en niveaux de hauteur, entièrement déterminé par une seed.
class Terrain {
  Terrain(this.seed);

  final int seed;
  final Map<int, int> _cache = {};

  /// Rayon (en cases) autour de l'origine forcé au niveau 0 pour un départ dégagé.
  static const int spawnClearRadius = 2;

  /// Niveau de hauteur (0..maxLevel) de la case (tx, ty).
  int levelAt(int tx, int ty) {
    final key = ((tx & 0xFFFF) << 16) | (ty & 0xFFFF);
    final cached = _cache[key];
    if (cached != null) return cached;
    final level = _compute(tx, ty);
    if (_cache.length > 60000) _cache.clear();
    _cache[key] = level;
    return level;
  }

  int _compute(int tx, int ty) {
    if (tx.abs() <= spawnClearRadius && ty.abs() <= spawnClearRadius) return 0;
    final n = fbm(seed, tx / 11.0, ty / 11.0);
    // Courbe : beaucoup de plaines, des plateaux, quelques sommets.
    const thresholds = [0.48, 0.58, 0.67, 0.75];
    var level = 0;
    for (final t in thresholds) {
      if (n >= t) level++;
    }
    return level.clamp(0, GameConfig.maxLevel);
  }

  /// Case contenant la position monde (x, y).
  static int tileOf(double v) => (v / GameConfig.tileSize).floor();

  int levelAtWorld(double x, double y) => levelAt(tileOf(x), tileOf(y));

  /// Chunk contenant une case.
  static int chunkOf(int tile) => (tile / GameConfig.chunkTiles).floor();
}

/// Règles de déplacement entre niveaux.
class HeightRules {
  HeightRules._();

  /// Le joueur peut-il entrer sur une case de niveau [target] ?
  /// Au sol : niveau inférieur ou égal (on peut descendre en se laissant tomber).
  /// En saut : jusqu'à +1 niveau.
  static bool playerCanEnter({required int current, required int target, required bool airborne}) {
    if (target <= current) return true;
    return airborne && target == current + 1;
  }

  /// Les ennemis restent sur leur niveau (pas de saut, pas de chute).
  static bool enemyCanEnter({required int current, required int target}) => target == current;
}
