import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint;

import 'package:flame/components.dart';
import 'package:flame/text.dart' show TextPaint;
import 'package:flutter/painting.dart' show FontWeight, Shadow, TextStyle;

/// Gerbe de particules (impact, mort d'ennemi, coffre ouvert).
class Burst extends PositionComponent {
  Burst({required Vector2 position, required Color color, int count = 12, double speed = 120, double life = 0.45})
      : _life = life,
        _maxLife = life,
        super(position: position, priority: 90) {
    final rng = math.Random();
    for (var i = 0; i < count; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final s = speed * (0.4 + rng.nextDouble() * 0.8);
      _parts.add(_Part(Vector2(math.cos(a) * s, math.sin(a) * s), 2 + rng.nextDouble() * 3));
    }
    _paint.color = color;
    _baseColor = color;
  }

  late final Color _baseColor;

  final List<_Part> _parts = [];
  final Paint _paint = Paint();
  double _life;
  final double _maxLife;

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    final damping = math.pow(0.05, dt).toDouble();
    for (final p in _parts) {
      p.pos.addScaled(p.vel, dt);
      p.vel.scale(damping);
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / _maxLife).clamp(0.0, 1.0);
    _paint.color = _baseColor.withValues(alpha: alpha);
    for (final p in _parts) {
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), p.size * alpha + 0.5, _paint);
    }
  }
}

class _Part {
  _Part(this.vel, this.size);
  final Vector2 pos = Vector2.zero();
  final Vector2 vel;
  final double size;
}

/// Texte qui monte et s'efface (ex. « +1 vie »).
class FloatingText extends TextComponent {
  FloatingText(String text, {required Vector2 position, Color color = const Color(0xFFFFFFFF)})
      : super(
          text: text,
          position: position,
          anchor: Anchor.center,
          priority: 120,
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
        );

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.y -= 30 * dt;
    if (_t > 0.9) removeFromParent();
  }
}
