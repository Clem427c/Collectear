import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/terrain.dart';
import 'collectear_game.dart';
import 'enemy.dart';
import 'sfx.dart';

class Player extends PositionComponent with HasGameReference<CollectearGame> {
  Player() : super(size: Vector2.all(22), anchor: Anchor.center, priority: 100);

  /// Niveau de hauteur sur lequel le joueur se tient.
  int level = 0;
  double _airTime = 0;
  final Vector2 facing = Vector2(1, 0);
  double _attackCd = 0;
  double _swing = 0;
  double _dodgeTime = 0;
  double _dodgeCd = 0;
  final Vector2 _dodgeDir = Vector2.zero();
  double _invincible = 0;

  bool get airborne => _airTime > 0;
  bool get dodging => _dodgeTime > 0;
  double get dodgeCooldownRatio => (_dodgeCd / GameConfig.dodgeCooldown).clamp(0, 1).toDouble();

  static const double _radius = 9;

  final _body = Paint()..color = const Color(0xFF7B5CFF);
  final _bodyHit = Paint()..color = const Color(0xFFFFFFFF);
  final _outline = Paint()
    ..color = const Color(0xFF1B1440)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _shadow = Paint()..color = const Color(0x55000000);
  final _eye = Paint()..color = const Color(0xFFFFFFFF);
  final _swingPaint = Paint()
    ..color = const Color(0xCCFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  final _dodgeTrail = Paint()..color = const Color(0x557B5CFF);

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.active) return;

    _attackCd = math.max(0, _attackCd - dt);
    _swing = math.max(0, _swing - dt);
    _dodgeCd = math.max(0, _dodgeCd - dt);
    _invincible = math.max(0, _invincible - dt);

    final wasAirborne = airborne;
    _airTime = math.max(0, _airTime - dt);

    Vector2 velocity;
    if (dodging) {
      _dodgeTime = math.max(0, _dodgeTime - dt);
      velocity = _dodgeDir * GameConfig.dodgeSpeed;
    } else {
      final input = game.moveInput;
      if (input.length2 > 0.01) facing.setFrom(input.normalized());
      velocity = input * GameConfig.playerSpeed * game.run.rules.speedMultiplier;
    }
    _move(velocity * dt);

    final under = game.terrain.levelAtWorld(position.x, position.y);
    if (wasAirborne && !airborne) {
      level = under; // atterrissage
    } else if (!airborne && under < level) {
      level = under; // on se laisse tomber
    }
  }

  void _move(Vector2 delta) {
    if (delta.x != 0) {
      final probeX = position.x + delta.x + delta.x.sign * _radius;
      if (_canEnter(probeX, position.y)) position.x += delta.x;
    }
    if (delta.y != 0) {
      final probeY = position.y + delta.y + delta.y.sign * _radius;
      if (_canEnter(position.x, probeY)) position.y += delta.y;
    }
  }

  bool _canEnter(double x, double y) {
    final target = game.terrain.levelAt(Terrain.tileOf(x), Terrain.tileOf(y));
    return HeightRules.playerCanEnter(current: level, target: target, airborne: airborne);
  }

  void jump() {
    if (airborne || !game.active) return;
    _airTime = GameConfig.jumpDuration;
    Sfx.play('jump', volume: 0.4);
  }

  void dodge() {
    if (_dodgeCd > 0 || dodging || !game.active) return;
    final input = game.moveInput;
    _dodgeDir.setFrom(input.length2 > 0.01 ? input.normalized() : facing);
    _dodgeTime = GameConfig.dodgeDuration;
    _dodgeCd = GameConfig.dodgeCooldown;
    Sfx.play('dodge', volume: 0.4);
  }

  void attack() {
    if (_attackCd > 0 || !game.active) return;
    _attackCd = GameConfig.attackCooldown;
    _swing = 0.15;
    Sfx.play('swing', volume: 0.35);
    for (final enemy in game.world.children.whereType<Enemy>().toList()) {
      if (enemy.level != level) continue;
      final toEnemy = enemy.position - position;
      final dist = toEnemy.length;
      if (dist > game.run.rules.attackRange + enemy.radius) continue;
      if (dist > 1 && toEnemy.normalized().dot(facing) < GameConfig.attackArcCos) continue;
      enemy.hit(toEnemy.length2 > 0 ? toEnemy.normalized() : facing);
    }
  }

  /// Le joueur reçoit un coup (ignoré pendant l'esquive et l'invincibilité).
  void takeHit() {
    if (_invincible > 0 || dodging || !game.active) return;
    _invincible = GameConfig.invincibleAfterHit;
    game.playerHit();
  }

  double get _jumpOffset {
    if (!airborne) return 0;
    final p = 1 - _airTime / GameConfig.jumpDuration; // 0 → 1
    return math.sin(p * math.pi) * GameConfig.jumpHeight;
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final lift = _jumpOffset;
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 8), width: 20 - lift * 0.3, height: 8 - lift * 0.15),
      _shadow,
    );
    if (dodging) {
      canvas.drawCircle(c - Offset(_dodgeDir.x, _dodgeDir.y) * 10, _radius, _dodgeTrail);
    }
    final body = c - Offset(0, lift);
    final blink = _invincible > 0 && (_invincible * 12).floor().isEven;
    canvas.drawCircle(body, _radius + 1, blink ? _bodyHit : _body);
    canvas.drawCircle(body, _radius + 1, _outline);
    canvas.drawCircle(body + Offset(facing.x, facing.y) * 5, 3, _eye);

    if (_swing > 0) {
      final angle = math.atan2(facing.y, facing.x);
      canvas.drawArc(
        Rect.fromCircle(center: body, radius: game.run.rules.attackRange * 0.8),
        angle - 1.1,
        2.2,
        false,
        _swingPaint,
      );
    }
  }
}
