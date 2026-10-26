import 'dart:math' as math;

import 'config.dart';
import 'noise.dart';
import 'terrain.dart';

/// Types de lieux à découvrir (GDD). Aucune indication n'est donnée au joueur :
/// il les trouve en explorant.
enum PlaceType { chest, rareChest, sanctuary, tower, ruin }

extension PlaceTypeInfo on PlaceType {
  String get label => const ['Coffre', 'Coffre rare', 'Sanctuaire', 'Tour', 'Ruine'][index];

  /// Bonus de chance de rareté de la carte obtenue.
  double get luckBonus => const [0.15, 0.6, 0.3, 0.35, 0.3][index];
}

class TilePos {
  const TilePos(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is TilePos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Description d'un lieu, calculée de façon déterministe à partir de la seed.
class PlaceSpec {
  const PlaceSpec({
    required this.type,
    required this.id,
    required this.tile,
    required this.level,
    this.guardians = const [],
    this.runes = const [],
  });

  final PlaceType type;
  final String id;
  final TilePos tile;
  final int level;

  /// Sanctuaire : ennemis gardiens à vaincre pour débloquer l'autel.
  final List<TilePos> guardians;

  /// Ruine : pierres runiques à activer (marcher dessus) pour ouvrir la ruine.
  final List<TilePos> runes;
}

/// Règles de génération des lieux d'un chunk.
class PlaceRules {
  PlaceRules._();

  static const int guardiansPerSanctuary = 4;
  static const int runesPerRuin = 3;

  /// Distance (en chunks) à partir de laquelle les coffres rares peuvent apparaître.
  static const double rareChestMinChunkDistance = 5;

  /// Lieux du chunk (cx, cy). Au plus un lieu par chunk, aucun près du départ.
  static List<PlaceSpec> forChunk(Terrain terrain, int cx, int cy) {
    if (cx.abs() <= 1 && cy.abs() <= 1) return const [];
    const n = GameConfig.chunkTiles;

    if (terrain.hasTower(cx, cy)) {
      final c = terrain.towerCenter(cx, cy);
      return [PlaceSpec(type: PlaceType.tower, id: 'tower:$cx:$cy', tile: c, level: terrain.levelAt(c.x, c.y))];
    }

    final rng = math.Random(hash3(terrain.seed ^ 0x51ac, cx, cy));
    final dist = math.sqrt(cx * cx + cy * cy).toDouble();
    final roll = rng.nextDouble();

    TilePos randomTile() => TilePos(cx * n + 1 + rng.nextInt(n - 2), cy * n + 1 + rng.nextInt(n - 2));

    if (roll < 0.08) {
      // Sanctuaire : autel entouré de gardiens.
      final t = randomTile();
      final offsets = [const TilePos(-2, 0), const TilePos(2, 0), const TilePos(0, -2), const TilePos(0, 2)];
      return [
        PlaceSpec(
          type: PlaceType.sanctuary,
          id: 'sanct:$cx:$cy',
          tile: t,
          level: terrain.levelAt(t.x, t.y),
          guardians: [for (final o in offsets.take(guardiansPerSanctuary)) TilePos(t.x + o.x, t.y + o.y)],
        ),
      ];
    }
    if (roll < 0.15) {
      // Ruine : 3 runes dispersées dans le chunk, la ruine au centre.
      final center = TilePos(cx * n + n ~/ 2, cy * n + n ~/ 2);
      final runes = <TilePos>[];
      while (runes.length < runesPerRuin) {
        final r = randomTile();
        if (r != center && !runes.contains(r)) runes.add(r);
      }
      return [
        PlaceSpec(
          type: PlaceType.ruin,
          id: 'ruin:$cx:$cy',
          tile: center,
          level: terrain.levelAt(center.x, center.y),
          runes: runes,
        ),
      ];
    }
    if (roll < 0.33) {
      // Coffre, de préférence sur le point le plus haut du chunk.
      var best = TilePos(cx * n, cy * n);
      var bestLevel = -1;
      for (var j = 0; j < n * n; j++) {
        final t = TilePos(cx * n + j % n, cy * n + j ~/ n);
        final l = terrain.levelAt(t.x, t.y);
        if (l > bestLevel || (l == bestLevel && rng.nextDouble() < 0.15)) {
          best = t;
          bestLevel = l;
        }
      }
      final rare = dist >= rareChestMinChunkDistance && rng.nextDouble() < 0.35;
      return [
        PlaceSpec(
          type: rare ? PlaceType.rareChest : PlaceType.chest,
          id: 'chest:$cx:$cy',
          tile: best,
          level: bestLevel,
        ),
      ];
    }
    return const [];
  }
}
