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
    this.runeGuards = const [],
  });

  final PlaceType type;
  final String id;
  final TilePos tile;
  final int level;

  /// Sanctuaire : ennemis gardiens à vaincre pour débloquer l'autel.
  final List<TilePos> guardians;

  /// Ruine : pierres runiques à activer (marcher dessus) pour ouvrir la ruine.
  final List<TilePos> runes;

  /// Ruine : ennemis postés autour des pierres runiques (ils ne verrouillent rien, ils défendent).
  final List<TilePos> runeGuards;
}

/// Règles de génération des lieux d'un chunk.
class PlaceRules {
  PlaceRules._();

  static const int guardiansPerSanctuary = 4;
  static const int runesPerRuin = 3;

  /// Ennemis autour de chaque pierre runique (retour de Clem du 27/10 : défi plus relevé).
  static const int guardsPerRune = 2;

  // Probabilités par chunk (hors tours). Retour de Clem du 27/10 : cartes trop faciles,
  // coffres simples moins fréquents ; lieux à défi (sanctuaire, ruine) un peu plus fréquents.
  static const double sanctuaryChance = 0.10; // avant : 0.08
  static const double ruinChance = 0.10; // avant : 0.07
  static const double chestChance = 0.06; // avant : 0.18

  /// Pas de coffre simple à moins de cette distance (en chunks) du départ.
  static const double chestMinChunkDistance = 3;

  /// Distance (en chunks) à partir de laquelle les coffres rares peuvent apparaître.
  static const double rareChestMinChunkDistance = 5;

  /// Places des gardiens autour de l'autel, à 3 cases au plus : de préférence au même étage que
  /// l'autel (les ennemis ne changent jamais d'étage ; sinon un gardien pouvait se retrouver
  /// coincé sur un autre étage, loin de l'autel — retour de Clem du 27/10).
  static const List<TilePos> guardianOffsets = [
    TilePos(2, 0), TilePos(-2, 0), TilePos(0, 2), TilePos(0, -2),
    TilePos(2, 2), TilePos(-2, -2), TilePos(2, -2), TilePos(-2, 2),
    TilePos(1, 2), TilePos(-1, -2), TilePos(2, 1), TilePos(-2, -1),
    TilePos(1, 1), TilePos(-1, -1), TilePos(1, -1), TilePos(-1, 1),
    TilePos(3, 0), TilePos(-3, 0), TilePos(0, 3), TilePos(0, -3),
  ];

  static List<TilePos> guardianTiles(Terrain terrain, TilePos altar, int level) {
    final out = <TilePos>[];
    for (final o in guardianOffsets) {
      if (out.length >= guardiansPerSanctuary) break;
      final g = TilePos(altar.x + o.x, altar.y + o.y);
      if (terrain.levelAt(g.x, g.y) == level && terrain.towerRing(g.x, g.y) == null) out.add(g);
    }
    // Relief très accidenté : on complète au plus près, même sur un autre étage.
    for (final o in guardianOffsets) {
      if (out.length >= guardiansPerSanctuary) break;
      final g = TilePos(altar.x + o.x, altar.y + o.y);
      if (!out.contains(g)) out.add(g);
    }
    return out;
  }

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

    if (roll < sanctuaryChance) {
      // Sanctuaire : autel entouré de gardiens.
      final t = randomTile();
      final level = terrain.levelAt(t.x, t.y);
      return [
        PlaceSpec(
          type: PlaceType.sanctuary,
          id: 'sanct:$cx:$cy',
          tile: t,
          level: level,
          guardians: guardianTiles(terrain, t, level),
        ),
      ];
    }
    if (roll < sanctuaryChance + ruinChance) {
      // Ruine : 3 runes dispersées dans le chunk, la ruine au centre.
      final center = TilePos(cx * n + n ~/ 2, cy * n + n ~/ 2);
      final runes = <TilePos>[];
      while (runes.length < runesPerRuin) {
        final r = randomTile();
        if (r != center && !runes.contains(r)) runes.add(r);
      }
      // Gardes : de part et d'autre de chaque rune, à 2 cases, sans sortir du chunk.
      final guards = <TilePos>[];
      const around = [TilePos(2, 0), TilePos(-2, 0), TilePos(0, 2), TilePos(0, -2), TilePos(2, 2), TilePos(-2, -2)];
      for (final r in runes) {
        var placed = 0;
        for (final o in around) {
          if (placed >= guardsPerRune) break;
          final g = TilePos(r.x + o.x, r.y + o.y);
          final inside = g.x >= cx * n && g.x < (cx + 1) * n && g.y >= cy * n && g.y < (cy + 1) * n;
          if (!inside || runes.contains(g) || guards.contains(g) || g == center) continue;
          guards.add(g);
          placed++;
        }
      }
      return [
        PlaceSpec(
          type: PlaceType.ruin,
          id: 'ruin:$cx:$cy',
          tile: center,
          level: terrain.levelAt(center.x, center.y),
          runes: runes,
          runeGuards: guards,
        ),
      ];
    }
    if (roll < sanctuaryChance + ruinChance + chestChance && dist >= chestMinChunkDistance) {
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
