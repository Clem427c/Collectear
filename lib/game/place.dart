import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/places.dart';
import 'collectear_game.dart';
import 'decor_art.dart';
import 'enemy.dart';

Vector2 tileCenter(TilePos t) => Vector2((t.x + 0.5) * GameConfig.tileSize, (t.y + 0.5) * GameConfig.tileSize);

/// Lieu à découvrir : coffre, coffre rare, sanctuaire, tour ou ruine.
class PlaceComponent extends PositionComponent with HasGameReference<CollectearGame> {
  PlaceComponent({required this.spec, this.guardiansLeft = 0, this.runesLit = 0})
      : super(position: tileCenter(spec.tile), size: Vector2.all(28), anchor: Anchor.center, priority: 40);

  final PlaceSpec spec;

  /// Sanctuaire : gardiens encore en vie.
  int guardiansLeft;

  /// Ruine : runes déjà activées.
  int runesLit;

  /// Sanctuaire : gardiens présents dans le monde (pour les relier à l'autel).
  final List<Enemy> guardianEnemies = [];

  double _t = 0;

  bool get unlocked => switch (spec.type) {
        PlaceType.sanctuary => guardiansLeft <= 0,
        PlaceType.ruin => runesLit >= spec.runes.length,
        _ => true,
      };

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!game.active || !unlocked) return;
    final p = game.player;
    if (!p.airborne && p.level == spec.level && p.position.distanceTo(position) < 20) {
      removeFromParent();
      game.placeCompleted(this);
    }
  }

  void guardianKilled() => guardiansLeft = math.max(0, guardiansLeft - 1);

  static final _tether = Paint()
    ..color = const Color(0x88FFC93C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  String? get _spriteName => switch (spec.type) {
        PlaceType.chest || PlaceType.tower => 'place_coffre',
        PlaceType.rareChest => 'place_coffre_rare',
        PlaceType.sanctuary => unlocked ? 'place_sanctuaire_eveille' : 'place_sanctuaire',
        PlaceType.ruin => unlocked ? 'place_ruine_ouverte' : 'place_ruine',
      };

  static const _spriteHeights = {
    PlaceType.chest: 26.0,
    PlaceType.tower: 26.0,
    PlaceType.rareChest: 28.0,
    PlaceType.sanctuary: 36.0,
    PlaceType.ruin: 44.0,
  };

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final pulse = math.sin(_t * 4);
    // Sanctuaire : un fil doré relie l'autel à chaque gardien encore en vie.
    if (spec.type == PlaceType.sanctuary && !unlocked) {
      for (final g in guardianEnemies) {
        if (!g.isMounted) continue;
        canvas.drawLine(c, c + Offset(g.position.x - position.x, g.position.y - position.y), _tether);
      }
    }
    final name = _spriteName;
    final h = _spriteHeights[spec.type]!;
    if (name != null && DecorArt.has(name)) {
      if (unlocked) {
        PlaceArt.glow(canvas, c, spec.type, pulse);
      }
      DecorArt.drawOnGround(canvas, name, c + const Offset(0, 10), h);
      PlaceArt.drawPips(canvas, c, spec.type,
          top: 10 - h, unlocked: unlocked, guardiansLeft: guardiansLeft, runesLit: runesLit, runeCount: spec.runes.length);
      return;
    }
    PlaceArt.draw(
      canvas,
      spec.type,
      c,
      pulse: pulse,
      unlocked: unlocked,
      guardiansLeft: guardiansLeft,
      runesLit: runesLit,
      runeCount: spec.runes.length,
    );
  }
}

/// Dessins des lieux, partagés entre le jeu et le guide (même apparence partout).
class PlaceArt {
  PlaceArt._();

  static final _gold = Paint()..color = const Color(0xFFFFB627);
  static final _goldDark = Paint()..color = const Color(0xFFE09400);
  static final _purple = Paint()..color = const Color(0xFFB57BFF);
  static final _purpleDark = Paint()..color = const Color(0xFF6B3FD6);
  static final _stone = Paint()..color = const Color(0xFF9A93B5);
  static final _stoneDark = Paint()..color = const Color(0xFF5E577A);
  static final _outline = Paint()
    ..color = const Color(0xFF2B1E10)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _glow = Paint();
  static final _orbOff = Paint()..color = const Color(0xFF4A4466);

  static void draw(Canvas canvas, PlaceType type, Offset c,
      {double pulse = 0, bool unlocked = true, int guardiansLeft = 0, int runesLit = 0, int runeCount = 3}) {
    switch (type) {
      case PlaceType.chest:
      case PlaceType.tower:
        _glow.color = const Color(0x33FFE066);
        canvas.drawCircle(c, 16 + 3 * pulse, _glow);
        _drawChest(canvas, c, _gold, _goldDark);
      case PlaceType.rareChest:
        _glow.color = const Color(0x55C79BFF);
        canvas.drawCircle(c, 19 + 4 * pulse, _glow);
        _drawChest(canvas, c, _purple, _purpleDark);
      case PlaceType.sanctuary:
        _drawAltar(canvas, c, pulse, unlocked, guardiansLeft);
      case PlaceType.ruin:
        _drawRuin(canvas, c, pulse, unlocked, runesLit, runeCount);
    }
  }

  static void _drawChest(Canvas canvas, Offset c, Paint body, Paint lid) {
    final r = Rect.fromCenter(center: c + const Offset(0, 3), width: 20, height: 13);
    canvas.drawRect(r, body);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top - 5, r.width, 6), lid);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top - 5, r.width, r.height + 5), _outline);
  }

  static void _drawAltar(Canvas canvas, Offset c, double pulse, bool unlocked, int guardiansLeft) {
    canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 6), width: 24, height: 10), _stoneDark);
    canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 2), width: 18, height: 8), _stone);
    if (unlocked) {
      _glow.color = const Color(0x66FFE066);
      canvas.drawCircle(c - const Offset(0, 6), 11 + 2 * pulse, _glow);
      canvas.drawCircle(c - const Offset(0, 6), 6, _gold);
    } else {
      canvas.drawCircle(c - const Offset(0, 6), 6, _orbOff);
      // Un point par gardien encore en vie.
      for (var i = 0; i < guardiansLeft; i++) {
        canvas.drawCircle(Offset(c.dx - (guardiansLeft - 1) * 4 + i * 8, c.dy - 18), 2.5, _stoneDark);
      }
    }
  }

  static void _drawRuin(Canvas canvas, Offset c, double pulse, bool unlocked, int runesLit, int runeCount) {
    // Arche de pierre ; l'intérieur s'illumine quand toutes les runes sont activées.
    canvas.drawRect(Rect.fromLTWH(c.dx - 13, c.dy - 10, 6, 20), _stone);
    canvas.drawRect(Rect.fromLTWH(c.dx + 7, c.dy - 10, 6, 20), _stone);
    canvas.drawRect(Rect.fromLTWH(c.dx - 13, c.dy - 14, 26, 6), _stoneDark);
    if (unlocked) {
      _glow.color = Color.fromARGB((120 + 60 * pulse).round(), 120, 220, 255);
      canvas.drawRect(Rect.fromLTWH(c.dx - 7, c.dy - 8, 14, 18), _glow);
    }
    for (var i = 0; i < runeCount; i++) {
      final lit = i < runesLit;
      _glow.color = lit ? const Color(0xFF7FE9FF) : const Color(0xFF4A4466);
      canvas.drawCircle(Offset(c.dx - 8 + i * 8, c.dy + 15), 2.5, _glow);
    }
  }

  /// Halo lumineux sous un lieu prêt à être ouvert.
  static void glow(Canvas canvas, Offset c, PlaceType type, double pulse) {
    _glow.color = switch (type) {
      PlaceType.rareChest => const Color(0x55C79BFF),
      PlaceType.ruin => const Color(0x5577E0FF),
      _ => const Color(0x44FFE066),
    };
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 6), width: 40 + 4 * pulse, height: 18 + 2 * pulse), _glow);
  }

  /// Indicateurs au-dessus du dessin : gardiens restants (sanctuaire), runes allumées (ruine).
  static void drawPips(Canvas canvas, Offset c, PlaceType type,
      {required double top, bool unlocked = true, int guardiansLeft = 0, int runesLit = 0, int runeCount = 3}) {
    if (type == PlaceType.sanctuary && !unlocked) {
      for (var i = 0; i < guardiansLeft; i++) {
        final p = Offset(c.dx - (guardiansLeft - 1) * 5 + i * 10, c.dy + top - 4);
        canvas.drawCircle(p, 3.5, _pipBack);
        canvas.drawCircle(p, 2.5, _pipGuard);
      }
    } else if (type == PlaceType.ruin) {
      for (var i = 0; i < runeCount; i++) {
        final p = Offset(c.dx - (runeCount - 1) * 5 + i * 10, c.dy + top - 4);
        canvas.drawCircle(p, 3.5, _pipBack);
        _glow.color = i < runesLit ? const Color(0xFF7FE9FF) : const Color(0xFF4A4466);
        canvas.drawCircle(p, 2.5, _glow);
      }
    }
  }

  static final _pipBack = Paint()..color = const Color(0xCC1B1440);
  static final _pipGuard = Paint()..color = const Color(0xFFFFC93C);

  /// Pierre runique (éteinte ou activée), centrée sur [c].
  static void drawRune(Canvas canvas, Offset c, {required bool lit, double shimmer = 0}) {
    canvas.drawCircle(c, 8, _runeStone);
    _runeLine.color = lit ? const Color(0xFF7FE9FF) : Color.fromARGB((90 + 40 * shimmer).round(), 200, 200, 255);
    final path = Path()
      ..moveTo(c.dx, c.dy - 5)
      ..lineTo(c.dx + 4, c.dy + 4)
      ..lineTo(c.dx - 4, c.dy + 4)
      ..close();
    canvas.drawPath(path, _runeLine);
  }

  static final _runeStone = Paint()..color = const Color(0xFF6E678C);
  static final _runeLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
}

/// Pierre runique d'une ruine : s'active quand le joueur passe dessus.
class RuneStone extends PositionComponent with HasGameReference<CollectearGame> {
  RuneStone({required TilePos tile, required this.level, required this.runeId, required this.ruin})
      : super(position: tileCenter(tile), size: Vector2.all(20), anchor: Anchor.center, priority: 35);

  final int level;
  final String runeId;
  final PlaceComponent? ruin;
  bool lit = false;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (lit || !game.active) return;
    final p = game.player;
    if (!p.airborne && p.level == level && p.position.distanceTo(position) < 16) {
      lit = true;
      game.runeActivated(this);
    }
  }

  @override
  void render(Canvas canvas) {
    if (DecorArt.drawOnGround(canvas, lit ? 'place_rune_active' : 'place_rune', const Offset(10, 15), 16)) return;
    PlaceArt.drawRune(canvas, const Offset(10, 10), lit: lit, shimmer: math.sin(_t * 2));
  }
}
