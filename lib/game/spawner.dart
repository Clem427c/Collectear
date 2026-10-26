import 'dart:math' as math;

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/noise.dart';
import '../core/terrain.dart';
import 'chest.dart';
import 'collectear_game.dart';
import 'enemy.dart';

/// Charge les entités des chunks proches du joueur et décharge les chunks lointains.
class Spawner extends Component with HasGameReference<CollectearGame> {
  static const int loadRadius = 2;
  static const int unloadRadius = 3;

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
      out.add(Enemy(
        kind: kind,
        level: terrain.levelAt(tx, ty),
        spawnId: id,
        position: _tileCenter(tx, ty),
        seed: enemySeed,
      ));
    }

    // Coffre : de préférence sur le point le plus haut du chunk (il faut sauter pour l'atteindre).
    if (rng.nextDouble() < 0.22) {
      final id = 'c:$cx:$cy';
      var best = -1;
      var bx = 0, by = 0;
      for (var j = 0; j < n * n; j++) {
        final tx = cx * n + j % n;
        final ty = cy * n + j ~/ n;
        final l = terrain.levelAt(tx, ty);
        if (l > best || (l == best && rng.nextDouble() < 0.15)) {
          best = l;
          bx = tx;
          by = ty;
        }
      }
      if (!consumed.contains(id)) {
        out.add(Chest(position: _tileCenter(bx, by), level: best, spawnId: id));
      }
    }

    game.world.addAll(out);
    return out;
  }

  Vector2 _tileCenter(int tx, int ty) =>
      Vector2((tx + 0.5) * GameConfig.tileSize, (ty + 0.5) * GameConfig.tileSize);
}
