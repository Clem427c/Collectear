import 'dart:math' as math;

import 'config.dart';
import 'economy.dart';
import 'noise.dart';
import 'places.dart';
import 'terrain.dart';

/// Élément de décor (purement visuel, on passe à travers) : arbre, buisson, rocher…
class Prop {
  const Prop(this.tx, this.ty, this.name, this.height, this.flip);
  final int tx;
  final int ty;

  /// Nom de l'image (assets/images/decors/<name>.png).
  final String name;

  /// Hauteur à l'écran, en cases.
  final double height;
  final bool flip;
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

  static const int minPerChunk = 3;
  static const int maxPerChunk = 6;

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
    final count = minPerChunk + rng.nextInt(maxPerChunk - minPerChunk + 1);
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
      final total = options.fold<int>(0, (s, o) => s + o.$3);
      var r = pick % total;
      for (final (name, h, w) in options) {
        if (r < w) {
          out.add(Prop(tx, ty, name, h, flip));
          break;
        }
        r -= w;
      }
    }
    // Du haut vers le bas : ceux de devant sont dessinés en dernier.
    out.sort((a, b) => a.ty != b.ty ? a.ty.compareTo(b.ty) : a.tx.compareTo(b.tx));
    return out;
  }
}
