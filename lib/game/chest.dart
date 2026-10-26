import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'collectear_game.dart';

/// Lieu à découvrir (prototype : un coffre). Donne une carte quand le joueur l'atteint.
class Chest extends PositionComponent with HasGameReference<CollectearGame> {
  Chest({required Vector2 position, required this.level, required this.spawnId})
      : super(position: position, size: Vector2.all(26), anchor: Anchor.center, priority: 40);

  final int level;
  final String spawnId;
  double _t = 0;

  final _box = Paint()..color = const Color(0xFFFFB627);
  final _lid = Paint()..color = const Color(0xFFE09400);
  final _outline = Paint()
    ..color = const Color(0xFF5A3A00)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _glow = Paint()..color = const Color(0x33FFE066);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (game.run.isOver) return;
    final p = game.player;
    if (!p.airborne && p.level == level && p.position.distanceTo(position) < 20) {
      removeFromParent();
      game.chestOpened(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(c, 16 + 3 * math.sin(_t * 4), _glow);
    final body = Rect.fromCenter(center: c + const Offset(0, 3), width: 20, height: 13);
    canvas.drawRect(body, _box);
    canvas.drawRect(Rect.fromLTWH(body.left, body.top - 5, body.width, 6), _lid);
    canvas.drawRect(Rect.fromLTWH(body.left, body.top - 5, body.width, body.height + 5), _outline);
  }
}
