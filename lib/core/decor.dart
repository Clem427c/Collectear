import 'dart:math' as math;

import 'biomes.dart';
import 'config.dart';
import 'economy.dart';
import 'noise.dart';
import 'places.dart';
import 'terrain.dart';

/// Élément de décor : arbre, buisson, rocher… Les gros (arbres, rochers, cristaux) peuvent bloquer
/// le passage (réglage « Décors solides », PROVISOIRE) ; les petits restent décoratifs.
class Prop {
  const Prop(this.tx, this.ty, this.name, this.height, this.flip);
  final int tx;
  final int ty;

  /// Nom de l'image (assets/images/decors/<name>.png).
  final String name;

  /// Hauteur à l'écran, en cases.
  final double height;
  final bool flip;

  /// Ce décor bloque-t-il le passage (quand les décors solides sont activés) ?
  bool get solid => DecorRules.solidNames.contains(name);

  /// Centre de l'obstacle, au pied du décor (unités du monde).
  double get footX => (tx + 0.5) * GameConfig.tileSize;
  double get footY => (ty + DecorRules.footOffset) * GameConfig.tileSize;
}

/// Répartition déterministe des décors d'un chunk, selon l'étage de chaque case.
class DecorRules {
  DecorRules._();

  /// (image, hauteur en cases, poids) par étage : plus c'est haut, plus c'est minéral.
  static const Map<int, List<(String, double, int)>> byLevel = {
    0: [
      ('prop_arbre_rond', 1.7, 4),
      ('prop_arbre_pin', 1.9, 3),
      ('prop_buisson', 0.9, 3),
      ('prop_champignons', 0.6, 2),
      ('prop_souche', 0.7, 1),
      ('prop_herbes_hautes', 0.7, 2),
    ],
    1: [
      ('prop_fleurs', 0.7, 4),
      ('prop_herbes_hautes', 0.7, 3),
      ('prop_buisson', 0.9, 2),
      ('prop_arbre_fruits', 1.5, 2),
      ('prop_rochers_petits', 0.5, 1),
    ],
    2: [
      ('prop_fleurs', 0.7, 2),
      ('prop_rochers_petits', 0.5, 3),
      ('prop_herbes_hautes', 0.7, 2),
      ('prop_rocher', 0.8, 2),
    ],
    3: [
      ('prop_rocher', 0.8, 4),
      ('prop_rochers_petits', 0.5, 3),
      ('prop_cristaux', 0.9, 2),
    ],
    4: [
      ('prop_arbre_enneige', 1.5, 4),
      ('prop_rocher', 0.8, 2),
      ('prop_cristaux', 0.9, 2),
    ],
  };

  /// PROVISOIRE (question à Clem) : décors qui bloquent le passage. Buissons, fleurs, herbes,
  /// champignons, souches et petits rochers restent traversables.
  static const Set<String> solidNames = {
    'prop_arbre_rond',
    'prop_arbre_pin',
    'prop_arbre_fruits',
    'prop_arbre_enneige',
    'prop_rocher',
    'prop_cristaux',
  };

  /// Position du pied du décor dans sa case (0 = haut, 1 = bas), là où il est dessiné.
  static const double footOffset = 0.8;

  static const int minPerChunk = 3;
  static const int maxPerChunk = 6;

  /// Plafond réel, biome compris (la forêt ajoute des décors).
  static const int maxPerChunkWithBiome = maxPerChunk + BiomeRules.maxExtraDecor;

  /// Pas de décor autour du départ (zone dégagée).
  static const int clearRadius = 3;

  /// Cases réservées du chunk : lieux, gardiens, runes, pièces (un décor ne doit rien cacher).
  static Set<(int, int)> reservedTiles(Terrain terrain, int worldSeed, int cx, int cy) {
    final out = <(int, int)>{};
    for (final p in PlaceRules.forChunk(terrain, cx, cy)) {
      for (final t in [p.tile, ...p.guardians, ...p.runes, ...p.runeGuards]) {
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            out.add((t.x + dx, t.y + dy));
          }
        }
      }
    }
    for (final (tx, ty, _) in Economy.coinsForChunk(worldSeed, cx, cy)) {
      out.add((tx, ty));
    }
    return out;
  }

  static List<Prop> propsForChunk(Terrain terrain, int worldSeed, int cx, int cy) {
    final rng = math.Random(hash3(worldSeed ^ 0xDEC0, cx, cy));
    const n = GameConfig.chunkTiles;
    final reserved = reservedTiles(terrain, worldSeed, cx, cy);
    final biomes = BiomeMap(worldSeed);
    final count = minPerChunk + rng.nextInt(maxPerChunk - minPerChunk + 1) + biomes.ofChunk(cx, cy).extraDecor;
    final out = <Prop>[];
    final used = <(int, int)>{};
    for (var attempt = 0; attempt < count * 4 && out.length < count; attempt++) {
      final tx = cx * n + rng.nextInt(n);
      final ty = cy * n + rng.nextInt(n);
      final pick = rng.nextInt(1 << 20);
      final flip = rng.nextBool();
      if (tx.abs() <= clearRadius && ty.abs() <= clearRadius) continue;
      if (reserved.contains((tx, ty)) || !used.add((tx, ty))) continue;
      if (terrain.towerRing(tx, ty) != null) continue;
      final options = byLevel[terrain.levelAt(tx, ty)]!;
      // Le biome de la case change le mélange (plus d'arbres en forêt, de rochers dans les rocailles).
      final biome = biomes.at(tx, ty);
      double weight((String, double, int) o) => o.$3 * biome.decorWeight(o.$1);
      final total = options.fold<double>(0, (s, o) => s + weight(o));
      var r = pick / (1 << 20) * total;
      for (var i = 0; i < options.length; i++) {
        final (name, h, _) = options[i];
        final w = weight(options[i]);
        if (r < w || i == options.length - 1) {
          final prop = Prop(tx, ty, name, h, flip);
          // Un décor solide est toujours isolé (aucun autre solide sur les 8 cases voisines, jamais au bord
          // du chunk pour ne pas toucher ceux du chunk voisin) : on peut donc toujours en faire le tour.
          if (!prop.solid || _isolated(prop, out, cx, cy)) out.add(prop);
          break;
        }
        r -= w;
      }
    }
    // Du haut vers le bas : ceux de devant sont dessinés en dernier.
    out.sort((a, b) => a.ty != b.ty ? a.ty.compareTo(b.ty) : a.tx.compareTo(b.tx));
    return out;
  }

  static bool _isolated(Prop p, List<Prop> placed, int cx, int cy) {
    const n = GameConfig.chunkTiles;
    final lx = p.tx - cx * n;
    final ly = p.ty - cy * n;
    if (lx <= 0 || ly <= 0 || lx >= n - 1 || ly >= n - 1) return false;
    return !placed.any((o) => o.solid && (o.tx - p.tx).abs() <= 1 && (o.ty - p.ty).abs() <= 1);
  }
}

/// Collisions du joueur avec les décors solides (cercles au pied des arbres et rochers).
class DecorCollision {
  DecorCollision._();

  /// Repousse un cercle (x, y, rayon r) hors des obstacles qu'il chevauche. Le joueur glisse ainsi le long
  /// d'un tronc au lieu de s'y arrêter net. Renvoie la position corrigée.
  static (double, double) pushOut(double x, double y, double r, Iterable<Prop> obstacles,
      {double obstacleRadius = GameConfig.propSolidRadius}) {
    var px = x, py = y;
    for (final o in obstacles) {
      if (!o.solid) continue;
      final dx = px - o.footX;
      final dy = py - o.footY;
      final minD = r + obstacleRadius;
      final d2 = dx * dx + dy * dy;
      if (d2 >= minD * minD) continue;
      final d = math.sqrt(d2);
      if (d < 1e-6) {
        py = o.footY + minD; // pile au centre : on ressort par le bas
      } else {
        px = o.footX + dx / d * minD;
        py = o.footY + dy / d * minD;
      }
    }
    return (px, py);
  }

  /// Le cercle (x, y, r) touche-t-il un obstacle ?
  static bool overlaps(double x, double y, double r, Iterable<Prop> obstacles,
      {double obstacleRadius = GameConfig.propSolidRadius}) {
    for (final o in obstacles) {
      if (!o.solid) continue;
      final dx = x - o.footX, dy = y - o.footY, minD = r + obstacleRadius - 0.01;
      if (dx * dx + dy * dy < minD * minD) return true;
    }
    return false;
  }
}
