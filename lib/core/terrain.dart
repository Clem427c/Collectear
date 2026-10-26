import 'dart:math' as math;

import 'config.dart';
import 'noise.dart';
import 'places.dart' show TilePos;

/// Terrain infini en niveaux de hauteur, entièrement déterminé par une seed.
class Terrain {
  Terrain(this.seed);

  final int seed;
  final Map<int, int> _cache = {};
  final Map<int, int> _rawCache = {};

  /// Rayon (en cases) autour de l'origine forcé au niveau 0 pour un départ dégagé.
  static const int spawnClearRadius = 2;

  static int _key(int tx, int ty) => ((tx & 0xFFFF) << 16) | (ty & 0xFFFF);

  /// Niveau de hauteur (0..maxLevel) de la case (tx, ty).
  ///
  /// Garantie : deux cases voisines (diagonales comprises) ne diffèrent jamais
  /// de plus d'un niveau. Comme un saut fait monter d'un niveau et qu'on peut
  /// toujours descendre, le joueur ne peut jamais se retrouver coincé.
  int levelAt(int tx, int ty) {
    final key = _key(tx, ty);
    final cached = _cache[key];
    if (cached != null) return cached;
    // Transformée de distance : L(p) = min sur q de raw(q) + distance(p, q).
    // C'est le plus haut relief possible sous le relief brut qui monte d'au plus 1 par case.
    var level = _raw(tx, ty);
    for (var r = 1; r <= GameConfig.maxLevel && r < level; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue; // seulement l'anneau de rayon r
          final v = _raw(tx + dx, ty + dy) + r;
          if (v < level) level = v;
        }
      }
    }
    if (_cache.length > 60000) _cache.clear();
    _cache[key] = level;
    return level;
  }

  int _raw(int tx, int ty) {
    final key = _key(tx, ty);
    final cached = _rawCache[key];
    if (cached != null) return cached;
    final v = _compute(tx, ty);
    if (_rawCache.length > 120000) _rawCache.clear();
    _rawCache[key] = v;
    return v;
  }

  // --- Tours : pyramides à gravir saut après saut, un coffre au sommet. ---

  /// Rayon d'une tour en cases (le sommet est au niveau maxLevel).
  static const int towerRadius = 3;

  /// Probabilité qu'un chunk contienne une tour.
  static const double towerChance = 0.05;

  bool hasTower(int cx, int cy) {
    if (cx.abs() <= 1 && cy.abs() <= 1) return false;
    return hash01(seed ^ 0x7031, cx, cy) < towerChance;
  }

  TilePos towerCenter(int cx, int cy) {
    const n = GameConfig.chunkTiles;
    return TilePos(cx * n + n ~/ 2, cy * n + n ~/ 2);
  }

  /// Distance (Chebyshev) au centre de la tour du chunk, ou null si hors tour.
  int? towerRing(int tx, int ty) {
    final cx = chunkOf(tx), cy = chunkOf(ty);
    if (!hasTower(cx, cy)) return null;
    final c = towerCenter(cx, cy);
    final d = math.max((tx - c.x).abs(), (ty - c.y).abs());
    return d <= towerRadius ? d : null;
  }

  int _compute(int tx, int ty) {
    if (tx.abs() <= spawnClearRadius && ty.abs() <= spawnClearRadius) return 0;
    final ring = towerRing(tx, ty);
    if (ring != null) return GameConfig.maxLevel - ring;
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
