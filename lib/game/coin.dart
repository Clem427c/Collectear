import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import 'collectear_game.dart';

/// Pièce (ou petit tas de pièces) posée au sol : ramassée en passant dessus, sur le même étage.
class CoinPickup extends PositionComponent with HasGameReference<CollectearGame> {
  CoinPickup({required int tx, required int ty, required this.level, required this.value, required this.coinId})
      : super(
          position: Vector2((tx + 0.5) * GameConfig.tileSize, (ty + 0.5) * GameConfig.tileSize),
          size: Vector2.all(16),
          anchor: Anchor.center,
          priority: 30,
        );

  final int level;
  final int value;
  final String coinId;
  double _t = math.Random().nextDouble() * 6;

  static final _gold = Paint()..color = const Color(0xFFFFC93C);
  static final _goldDark = Paint()..color = const Color(0xFFD99A00);
  static final _shine = Paint()..color = const Color(0xFFFFF4C2);
  static final _shadow = Paint()..color = const Color(0x44000000);

  bool get isPile => value > 1;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!game.active) return;
    final p = game.player;
    final d2 = p.position.distanceToSquared(position);
    _visible = d2 < 256 * GameConfig.tileSize * GameConfig.tileSize; // 16 cases : hors écran au-delà
    final r = isPile ? 18 : 15;
    if (p.level == level && d2 < r * r) {
      removeFromParent();
      game.coinCollected(this);
    }
  }

  bool _visible = true;

  @override
  void render(Canvas canvas) {
    if (!_visible) return;
    final bob = math.sin(_t * 3) * 1.5;
    canvas.drawOval(const Rect.fromLTWH(3, 12, 10, 4), _shadow);
    if (isPile) {
      for (final o in const [Offset(4, 9), Offset(12, 9), Offset(8, 5)]) {
        _coin(canvas, o + Offset(0, bob), 4.5);
      }
    } else {
      // Pièce qui tourne : on écrase sa largeur.
      final squash = 0.35 + 0.65 * math.cos(_t * 4).abs();
      canvas.save();
      canvas.translate(8, 7 + bob);
      canvas.scale(squash, 1);
      _coin(canvas, Offset.zero, 5.5);
      canvas.restore();
    }
  }

  void _coin(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, _goldDark);
    canvas.drawCircle(c, r - 1.3, _gold);
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.3), r * 0.25, _shine);
  }
}
