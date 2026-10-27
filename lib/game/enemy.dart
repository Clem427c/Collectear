import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/terrain.dart';
import 'collectear_game.dart';
import 'decor_art.dart';
import 'effects.dart';
import 'place.dart';
import 'projectile.dart';
import 'sfx.dart';

enum EnemyKind { melee, ranged }

enum _State { patrol, chase, telegraph, recover }

class Enemy extends PositionComponent with HasGameReference<CollectearGame> {
  Enemy({
    required this.kind,
    required this.level,
    required this.spawnId,
    required Vector2 position,
    required int seed,
    this.guardOf,
    bool guard = false,
  })  : _rng = math.Random(seed),
        isGuard = guard || guardOf != null,
        home = position.clone(),
        super(position: position, size: Vector2.all(24), anchor: Anchor.center, priority: 50);

  /// Gardien (sanctuaire ou pierre runique) : apparence d'élite et reste près de son poste.
  final bool isGuard;

  /// Poste du gardien.
  final Vector2 home;

  /// Un gardien patrouille dans ce rayon autour de son poste et ne poursuit pas au-delà de
  /// [_chaseLeash] (retour de Clem du 27/10 : les gardiens d'un sanctuaire s'éloignaient).
  static const double _leash = 1.5 * GameConfig.tileSize;
  static const double _chaseLeash = 4.5 * GameConfig.tileSize;

  final EnemyKind kind;
  final int level;
  final String spawnId;

  /// Sanctuaire gardé par cet ennemi (null pour un ennemi ordinaire).
  final PlaceComponent? guardOf;
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
    if (!game.active) return;
    _flash = math.max(0, _flash - dt);

    if (_knock.length2 > 1) {
      _move(_knock * dt);
      _knock.scale(math.pow(0.02, dt).toDouble());
    }

    final player = game.player;
    // Optimisation : un ennemi hors de l'écran qui patrouille ne fait rien (ni calcul, ni dessin).
    final dx = player.position.x - position.x;
    final dy = player.position.y - position.y;
    final d2 = dx * dx + dy * dy;
    _offscreen = d2 > _farDistance * _farDistance;
    if (_offscreen && _state == _State.patrol && _knock.length2 <= 1) return;
    final toPlayer = Vector2(dx, dy);
    final dist = math.sqrt(d2);
    final sameLevel = player.level == level;
    // Période de grâce au début de la run : les ennemis ne repèrent pas encore le joueur.
    var sees = sameLevel && dist < GameConfig.detectRadius && game.run.elapsed > GameConfig.startGrace;
    if (isGuard && position.distanceTo(home) > _chaseLeash) sees = false; // retourne à son poste

    switch (_state) {
      case _State.patrol:
        _timer -= dt;
        if (_timer <= 0) _pickWander();
        if (isGuard && position.distanceTo(home) > _leash) {
          // Revient vers son poste.
          _wander.setFrom(home - position);
          _wander.normalize();
        }
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
      Sfx.play('shoot', volume: 0.3);
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
    Sfx.play('hit', volume: 0.5);
    Sfx.haptic(HapticStrength.light);
    game.world.add(Burst(position: position.clone(), color: const Color(0xFFFFFFFF), count: 6, speed: 90, life: 0.25));
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

  /// Au-delà, l'ennemi est hors de l'écran (vue ≈ 11 cases sur le petit côté).
  static const double _farDistance = 16 * GameConfig.tileSize;
  bool _offscreen = false;
  Path? _diamond;

  @override
  void render(Canvas canvas) {
    if (_offscreen) return;
    final c = Offset(size.x / 2, size.y / 2);
    if (isGuard) {
      // Anneau doré sous les gardiens : on voit tout de suite lesquels défendent le lieu.
      canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 9), width: 30, height: 12), _guardRing);
    }
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 9), width: 20, height: 7), _shadow);
    if (_renderSprite(canvas, c)) {
      _renderOverlay(canvas, c, -16);
      return;
    }
    final paint = _flash > 0 ? _flashPaint : (kind == EnemyKind.melee ? _meleePaint : _rangedPaint);
    if (kind == EnemyKind.melee) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 20, height: 20), const Radius.circular(5));
      canvas.drawRRect(r, paint);
      canvas.drawRRect(r, _outline);
    } else {
      final path = _diamond ??= Path()
        ..moveTo(c.dx, c.dy - 12)
        ..lineTo(c.dx + 11, c.dy)
        ..lineTo(c.dx, c.dy + 12)
        ..lineTo(c.dx - 11, c.dy)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, _outline);
    }
    _renderOverlay(canvas, c, 0);
  }

  static final _guardRing = Paint()
    ..color = const Color(0xCCFFC93C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  String get _spriteName => switch ((kind, isGuard)) {
        (EnemyKind.melee, false) => 'ennemi_cac',
        (EnemyKind.melee, true) => 'ennemi_cac_elite',
        (EnemyKind.ranged, false) => 'ennemi_distance',
        (EnemyKind.ranged, true) => 'ennemi_distance_elite',
      };

  bool _renderSprite(Canvas canvas, Offset c) {
    final h = isGuard ? 36.0 : 30.0;
    return DecorArt.drawOnGround(canvas, _spriteName, c + const Offset(0, 10), h,
        flipX: game.player.position.x < position.x, flash: _flash > 0 ? const Color(0xDDFFFFFF) : null);
  }

  /// Cercle d'attaque imminente et points de vie (au-dessus de la tête, [lift] pour les grands dessins).
  void _renderOverlay(Canvas canvas, Offset c, double lift) {
    if (_state == _State.telegraph) {
      final total = kind == EnemyKind.melee ? GameConfig.meleeTelegraph : GameConfig.rangedTelegraph;
      final p = 1 - (_timer / total).clamp(0.0, 1.0);
      canvas.drawCircle(c, 14 + 10 * (1 - p), _telegraph);
    }
    for (var i = 0; i < maxHp; i++) {
      canvas.drawCircle(Offset(c.dx - (maxHp - 1) * 4 + i * 8, c.dy - 17 + lift), 2.5, i < hp ? _pip : _pipEmpty);
    }
  }
}
