import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import 'collectear_game.dart';

/// Tir ennemi : touche le joueur s'il est au même niveau, s'écrase sur le relief plus haut.
class Projectile extends PositionComponent with HasGameReference<CollectearGame> {
  Projectile({required Vector2 position, required this.velocity, required this.level})
      : super(position: position, size: Vector2.all(10), anchor: Anchor.center, priority: 80);

  final Vector2 velocity;
  final int level;
  double _life = GameConfig.projectileLife;

  final _paint = Paint()..color = const Color(0xFFFFE066);
  final _core = Paint()..color = const Color(0xFFFF6B00);

  @override
  void update(double dt) {
    super.update(dt);
    if (game.run.isOver) return;
    position.add(velocity * dt);
    _life -= dt;
    if (_life <= 0 || game.terrain.levelAtWorld(position.x, position.y) > level) {
      removeFromParent();
      return;
    }
    final player = game.player;
    if (player.level == level && player.position.distanceTo(position) < 13) {
      player.takeHit();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(const Offset(5, 5), 5, _paint);
    canvas.drawCircle(const Offset(5, 5), 2.5, _core);
  }
}
