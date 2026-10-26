import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/places.dart';
import 'collectear_game.dart';

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

  double _t = 0;

  bool get unlocked => switch (spec.type) {
        PlaceType.sanctuary => guardiansLeft <= 0,
        PlaceType.ruin => runesLit >= spec.runes.length,
        _ => true,
      };

  final _gold = Paint()..color = const Color(0xFFFFB627);
  final _goldDark = Paint()..color = const Color(0xFFE09400);
  final _purple = Paint()..color = const Color(0xFFB57BFF);
  final _purpleDark = Paint()..color = const Color(0xFF6B3FD6);
  final _stone = Paint()..color = const Color(0xFF9A93B5);
  final _stoneDark = Paint()..color = const Color(0xFF5E577A);
  final _outline = Paint()
    ..color = const Color(0xFF2B1E10)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _glow = Paint();
  final _orbOff = Paint()..color = const Color(0xFF4A4466);

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

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final pulse = math.sin(_t * 4);
    switch (spec.type) {
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
        _drawAltar(canvas, c, pulse);
      case PlaceType.ruin:
        _drawRuin(canvas, c, pulse);
    }
  }

  void _drawChest(Canvas canvas, Offset c, Paint body, Paint lid) {
    final r = Rect.fromCenter(center: c + const Offset(0, 3), width: 20, height: 13);
    canvas.drawRect(r, body);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top - 5, r.width, 6), lid);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top - 5, r.width, r.height + 5), _outline);
  }

  void _drawAltar(Canvas canvas, Offset c, double pulse) {
    canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 6), width: 24, height: 10), _stoneDark);
    canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 2), width: 18, height: 8), _stone);
    if (unlocked) {
      _glow.color = const Color(0x66FFE066);
      canvas.drawCircle(c - const Offset(0, 6), 11 + 2 * pulse, _glow);
      canvas.drawCircle(c - const Offset(0, 6), 6, _gold);
    } else {
      canvas.drawCircle(c - const Offset(0, 6), 6, _orbOff);
      for (var i = 0; i < guardiansLeft; i++) {
        canvas.drawCircle(Offset(c.dx - (guardiansLeft - 1) * 4 + i * 8, c.dy - 18), 2.5, _stoneDark);
      }
    }
  }

  void _drawRuin(Canvas canvas, Offset c, double pulse) {
    // Arche de pierre ; l'intérieur s'illumine quand toutes les runes sont activées.
    canvas.drawRect(Rect.fromLTWH(c.dx - 13, c.dy - 10, 6, 20), _stone);
    canvas.drawRect(Rect.fromLTWH(c.dx + 7, c.dy - 10, 6, 20), _stone);
    canvas.drawRect(Rect.fromLTWH(c.dx - 13, c.dy - 14, 26, 6), _stoneDark);
    if (unlocked) {
      _glow.color = Color.fromARGB((120 + 60 * pulse).round(), 120, 220, 255);
      canvas.drawRect(Rect.fromLTWH(c.dx - 7, c.dy - 8, 14, 18), _glow);
    }
    for (var i = 0; i < spec.runes.length; i++) {
      final lit = i < runesLit;
      _glow.color = lit ? const Color(0xFF7FE9FF) : const Color(0xFF4A4466);
      canvas.drawCircle(Offset(c.dx - 8 + i * 8, c.dy + 15), 2.5, _glow);
    }
  }
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

  final _stone = Paint()..color = const Color(0xFF6E678C);
  final _rune = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

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
    const c = Offset(10, 10);
    canvas.drawCircle(c, 8, _stone);
    _rune.color = lit ? const Color(0xFF7FE9FF) : Color.fromARGB((90 + 40 * math.sin(_t * 2)).round(), 200, 200, 255);
    final path = Path()
      ..moveTo(c.dx, c.dy - 5)
      ..lineTo(c.dx + 4, c.dy + 4)
      ..lineTo(c.dx - 4, c.dy + 4)
      ..close();
    canvas.drawPath(path, _rune);
  }
}
