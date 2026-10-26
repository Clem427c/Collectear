import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/terrain.dart';
import 'collectear_game.dart';
import 'projectile.dart';

enum EnemyKind { melee, ranged }

enum _State { patrol, chase, telegraph, recover }

class Enemy extends PositionComponent with HasGameReference<CollectearGame> {
  Enemy({
    required this.kind,
    required this.level,
    required this.spawnId,
    required Vector2 position,
    required int seed,
  })  : _rng = math.Random(seed),
        super(position: position, size: Vector2.all(24), anchor: Anchor.center, priority: 50);

  final EnemyKind kind;
  final int level;
  final String spawnId;
  final math.Random _rng;

  late int hp;
  late int maxHp;
  _State _state = _State.patrol;
  double _timer = 0;
  double _flash = 0;
  final Vector2 _wander = Vector2.zero();
  final Vector2 _knock = Vector2.zero();
  final Vector2 _aim = Vector2.zero();

  double get radius => 11;

  final _meleePaint = Paint()..color = const Color(0xFFE84A5F);
  final _rangedPaint = Paint()..color = const Color(0xFFFF9F1C);
  final _flashPaint = Paint()..color = const Color(0xFFFFFFFF);
  final _outline = Paint()
    ..color = const Color(0xFF2B1A1A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _telegraph = Paint()
    ..color = const Color(0xCCFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final _pip = Paint()..color = const Color(0xFF1B1440);
  final _pipEmpty = Paint()..color = const Color(0x551B1440);
  final _shadow = Paint()..color = const Color(0x44000000);

  @override
  Future<void> onLoad() async {
    maxHp = game.run.rules.enemyHitsToKill;
    hp = maxHp;
    _pickWander();
  }

  void _pickWander() {
    final a = _rng.nextDouble() * math.pi * 2;
    _wander.setValues(math.cos(a), math.sin(a));
    _timer = 1 + _rng.nextDouble() * 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.run.isOver) return;
    _flash = math.max(0, _flash - dt);

    if (_knock.length2 > 1) {
      _move(_knock * dt);
      _knock.scale(math.pow(0.02, dt).toDouble());
    }

    final player = game.player;
    final toPlayer = player.position - position;
    final dist = toPlayer.length;
    final sameLevel = player.level == level;
    // Période de grâce au début de la run : les ennemis ne repèrent pas encore le joueur.
    final sees = sameLevel && dist < GameConfig.detectRadius && game.run.elapsed > GameConfig.startGrace;

    switch (_state) {
      case _State.patrol:
        _timer -= dt;
        if (_timer <= 0) _pickWander();
        _move(_wander * (_speed * 0.4) * dt);
        if (sees) {
          _state = _State.chase;
          // Laisse au joueur le temps de réagir avant le premier tir.
          _timer = GameConfig.rangedCooldown * 0.75;
        }
      case _State.chase:
        if (!sees) {
          _state = _State.patrol;
          break;
        }
        if (kind == EnemyKind.melee) {
          if (dist <= GameConfig.meleeRange) {
            _startTelegraph(GameConfig.meleeTelegraph, toPlayer);
          } else {
            _move(toPlayer.normalized() * _speed * dt);
          }
        } else {
          final pref = GameConfig.rangedPreferredDistance;
          if (dist < pref - 24) {
            _move(-toPlayer.normalized() * _speed * dt);
          } else if (dist > pref + 24) {
            _move(toPlayer.normalized() * _speed * dt);
          }
          _timer -= dt;
          if (_timer <= 0) _startTelegraph(GameConfig.rangedTelegraph, toPlayer);
        }
      case _State.telegraph:
        _timer -= dt;
        if (_timer <= 0) _strike();
      case _State.recover:
        _timer -= dt;
        if (_timer <= 0) {
          _state = _State.chase;
          _timer = kind == EnemyKind.ranged ? GameConfig.rangedCooldown : 0;
        }
    }
  }

  double get _speed => kind == EnemyKind.melee ? GameConfig.meleeSpeed : GameConfig.rangedSpeed;

  void _startTelegraph(double duration, Vector2 toPlayer) {
    _state = _State.telegraph;
    _timer = duration;
    _aim.setFrom(toPlayer.length2 > 0 ? toPlayer.normalized() : Vector2(1, 0));
  }

  void _strike() {
    final player = game.player;
    if (kind == EnemyKind.melee) {
      final dist = player.position.distanceTo(position);
      if (dist <= GameConfig.meleeRange * 1.35 && player.level == level) player.takeHit();
      _state = _State.recover;
      _timer = GameConfig.enemyAttackCooldown;
    } else {
      final dir = (player.position - position);
      final aim = dir.length2 > 0 ? dir.normalized() : _aim;
      game.world.add(Projectile(position: position.clone(), velocity: aim * GameConfig.projectileSpeed, level: level));
      _state = _State.recover;
      _timer = 0.4;
    }
  }

  void _move(Vector2 delta) {
    final nx = position.x + delta.x;
    final ny = position.y + delta.y;
    final t = game.terrain;
    if (HeightRules.enemyCanEnter(
        current: level, target: t.levelAt(Terrain.tileOf(nx + delta.x.sign * radius), Terrain.tileOf(position.y)))) {
      position.x = nx;
    } else if (_state == _State.patrol) {
      _wander.x = -_wander.x;
    }
    if (HeightRules.enemyCanEnter(
        current: level, target: t.levelAt(Terrain.tileOf(position.x), Terrain.tileOf(ny + delta.y.sign * radius)))) {
      position.y = ny;
    } else if (_state == _State.patrol) {
      _wander.y = -_wander.y;
    }
  }

  /// Reçoit un coup du joueur.
  void hit(Vector2 direction) {
    hp--;
    _flash = 0.12;
    _knock.setFrom(direction * 260);
    if (_state == _State.telegraph) {
      _state = _State.recover;
      _timer = 0.35;
    }
    if (hp <= 0) {
      removeFromParent();
      game.enemyKilled(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 9), width: 20, height: 7), _shadow);
    final paint = _flash > 0 ? _flashPaint : (kind == EnemyKind.melee ? _meleePaint : _rangedPaint);
    if (kind == EnemyKind.melee) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 20, height: 20), const Radius.circular(5));
      canvas.drawRRect(r, paint);
      canvas.drawRRect(r, _outline);
    } else {
      final path = Path()
        ..moveTo(c.dx, c.dy - 12)
        ..lineTo(c.dx + 11, c.dy)
        ..lineTo(c.dx, c.dy + 12)
        ..lineTo(c.dx - 11, c.dy)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, _outline);
    }
    if (_state == _State.telegraph) {
      final total = kind == EnemyKind.melee ? GameConfig.meleeTelegraph : GameConfig.rangedTelegraph;
      final p = 1 - (_timer / total).clamp(0.0, 1.0);
      canvas.drawCircle(c, 14 + 10 * (1 - p), _telegraph);
    }
    for (var i = 0; i < maxHp; i++) {
      canvas.drawCircle(Offset(c.dx - (maxHp - 1) * 4 + i * 8, c.dy - 17), 2.5, i < hp ? _pip : _pipEmpty);
    }
  }
}
