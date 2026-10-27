import 'dart:math' as math;

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/economy.dart';
import '../core/noise.dart';
import '../core/terrain.dart';
import '../core/places.dart';
import 'coin.dart';
import 'collectear_game.dart';
import 'enemy.dart';
import 'place.dart';

/// Charge les entités des chunks proches du joueur et décharge les chunks lointains.
class Spawner extends Component with HasGameReference<CollectearGame> {
  static const int loadRadius = 2;
  static const int unloadRadius = 3;
  static const int safeRadius = 7; // en cases

  final Map<(int, int), List<Component>> _loaded = {};
  final Set<String> consumed = {};
  double _timer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _timer -= dt;
    if (_timer > 0) return;
    _timer = 0.25;

    final p = game.player.position;
    final pcx = Terrain.chunkOf(Terrain.tileOf(p.x));
    final pcy = Terrain.chunkOf(Terrain.tileOf(p.y));

    for (var cy = pcy - loadRadius; cy <= pcy + loadRadius; cy++) {
      for (var cx = pcx - loadRadius; cx <= pcx + loadRadius; cx++) {
        if (!_loaded.containsKey((cx, cy))) _loaded[(cx, cy)] = _loadChunk(cx, cy);
      }
    }
    final far = _loaded.keys
        .where((k) => (k.$1 - pcx).abs() > unloadRadius || (k.$2 - pcy).abs() > unloadRadius)
        .toList();
    for (final k in far) {
      for (final c in _loaded.remove(k)!) {
        if (c.isMounted) c.removeFromParent();
      }
    }
  }

  List<Component> _loadChunk(int cx, int cy) {
    final out = <Component>[];
    if (cx == 0 && cy == 0) return out;
    final seed = hash3(game.seed, cx, cy);
    final rng = math.Random(seed);
    final terrain = game.terrain;
    const n = GameConfig.chunkTiles;
    final dist = math.sqrt(cx * cx + cy * cy);

    // Ennemis : plus nombreux en s'éloignant du départ.
    final count = rng.nextInt(2) + (dist > 2 ? 1 : 0) + (dist > 6 ? 1 : 0);
    for (var i = 0; i < count; i++) {
      final id = 'e:$cx:$cy:$i';
      final tx = cx * n + rng.nextInt(n);
      final ty = cy * n + rng.nextInt(n);
      final kind = rng.nextDouble() < 0.6 ? EnemyKind.melee : EnemyKind.ranged;
      final enemySeed = rng.nextInt(1 << 30);
      if (consumed.contains(id)) continue;
      // Pas d'ennemi dans les premières cases autour du départ.
      if (tx.abs() < safeRadius && ty.abs() < safeRadius) continue;
      out.add(Enemy(
        kind: kind,
        level: terrain.levelAt(tx, ty),
        spawnId: id,
        position: _tileCenter(tx, ty),
        seed: enemySeed,
      ));
    }

    // Pièces au sol (bien plus courantes que les cartes).
    final coins = Economy.coinsForChunk(game.seed, cx, cy);
    for (var i = 0; i < coins.length; i++) {
      final (tx, ty, value) = coins[i];
      final id = 'c:$cx:$cy:$i';
      if (consumed.contains(id)) continue;
      out.add(CoinPickup(tx: tx, ty: ty, level: terrain.levelAt(tx, ty), value: value, coinId: id));
    }

    // Lieux : coffre, coffre rare, sanctuaire, tour ou ruine.
    for (final spec in PlaceRules.forChunk(terrain, cx, cy)) {
      if (consumed.contains(spec.id)) continue;
      final guardianIds = [for (var g = 0; g < spec.guardians.length; g++) '${spec.id}:g$g'];
      final runeIds = [for (var r = 0; r < spec.runes.length; r++) '${spec.id}:r$r'];
      final place = PlaceComponent(
        spec: spec,
        guardiansLeft: guardianIds.where((id) => !consumed.contains(id)).length,
        runesLit: runeIds.where(consumed.contains).length,
      );
      out.add(place);
      for (var g = 0; g < spec.guardians.length; g++) {
        if (consumed.contains(guardianIds[g])) continue;
        final t = spec.guardians[g];
        final guardian = Enemy(
          kind: g.isEven ? EnemyKind.melee : EnemyKind.ranged,
          level: terrain.levelAt(t.x, t.y),
          spawnId: guardianIds[g],
          position: tileCenter(t),
          seed: rng.nextInt(1 << 30),
          guardOf: place,
        );
        place.guardianEnemies.add(guardian);
        out.add(guardian);
      }
      for (var k = 0; k < spec.runeGuards.length; k++) {
        final id = '${spec.id}:k$k';
        final t = spec.runeGuards[k];
        final kindSeed = rng.nextInt(1 << 30);
        if (consumed.contains(id)) continue;
        out.add(Enemy(
          kind: k.isEven ? EnemyKind.melee : EnemyKind.ranged,
          level: terrain.levelAt(t.x, t.y),
          spawnId: id,
          position: tileCenter(t),
          seed: kindSeed,
          guard: true,
        ));
      }
      for (var r = 0; r < spec.runes.length; r++) {
        final t = spec.runes[r];
        out.add(RuneStone(tile: t, level: terrain.levelAt(t.x, t.y), runeId: runeIds[r], ruin: place)
          ..lit = consumed.contains(runeIds[r]));
      }
    }

    game.world.addAll(out);
    return out;
  }

  Vector2 _tileCenter(int tx, int ty) =>
      Vector2((tx + 0.5) * GameConfig.tileSize, (ty + 0.5) * GameConfig.tileSize);
}
