import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/combat.dart';
import '../core/config.dart';
import '../core/terrain.dart';
import 'collectear_game.dart';
import 'decor_art.dart';
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

  late final _body = Paint()..color = Color(game.skin.isDefault ? 0xFF7B5CFF : game.skin.dark);
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
      if (!HeightRules.playerCanHit(attacker: level, target: enemy.level)) continue;
      final toEnemy = enemy.position - position;
      if (!playerAttackHits(
        dx: toEnemy.x,
        dy: toEnemy.y,
        facingX: facing.x,
        facingY: facing.y,
        range: game.run.rules.attackRange,
        enemyRadius: enemy.radius,
      )) {
        continue;
      }
      enemy.hit(toEnemy.length2 > 0 ? toEnemy.normalized() : facing);
    }
  }

  /// Rend le joueur intouchable un moment (résurrection).
  void makeInvincible(double seconds) => _invincible = math.max(_invincible, seconds);

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
    final blink = _invincible > 0 && (_invincible * 12).floor().isEven;
    if (_renderSprite(canvas, c, lift, blink)) return;
    if (dodging) {
      canvas.drawCircle(c - Offset(_dodgeDir.x, _dodgeDir.y) * 10, _radius, _dodgeTrail);
    }
    final body = c - Offset(0, lift);
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

  /// Hauteur de l'explorateur à l'écran (unités du monde).
  static const double _spriteHeight = 40;

  /// Explorateur dessiné (images générées) : face, dos ou profil selon la direction, pose
  /// d'attaque pendant un coup. Renvoie false si les images manquent (dessin de secours).
  bool _renderSprite(Canvas canvas, Offset c, double lift, bool blink) {
    final String name;
    var flip = facing.x < 0;
    if (_swing > 0) {
      name = 'perso_explorateur_attaque';
    } else if (facing.y > facing.x.abs()) {
      name = 'perso_explorateur_face';
      flip = false;
    } else if (-facing.y > facing.x.abs()) {
      name = 'perso_explorateur_dos';
      flip = false;
    } else {
      name = 'perso_explorateur_profil';
    }
    if (!DecorArt.has(name)) return false;
    final foot = c + Offset(0, 9 - lift);
    if (dodging) {
      DecorArt.drawOnGround(canvas, name, foot - Offset(_dodgeDir.x, _dodgeDir.y) * 10, _spriteHeight,
          flipX: flip, opacity: 0.35);
    }
    // Petit rebond pendant la marche.
    final moving = game.moveInput.length2 > 0.01 && !airborne;
    final bob = moving ? (math.sin(game.run.elapsed * 18).abs() * 2) : 0.0;
    final skin = game.skin;
    DecorArt.drawOnGround(canvas, name, foot - Offset(0, bob), _spriteHeight,
        flipX: flip, opacity: blink ? 0.35 : 1, tint: Color(skin.dark), tintStrength: skin.tintStrength);
    if (_swing > 0) {
      final angle = math.atan2(facing.y, facing.x);
      canvas.drawArc(
        Rect.fromCircle(center: c - Offset(0, lift + 8), radius: game.run.rules.attackRange * 0.8),
        angle - 1.1,
        2.2,
        false,
        _swingPaint,
      );
    }
    return true;
  }
}
