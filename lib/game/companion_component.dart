import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../app_data.dart' show Illustrations;
import '../core/companion.dart';
import '../core/variants.dart';
import '../ui/widgets.dart' show variantMatrix;
import 'collectear_game.dart';

/// Compagnon de run dessiné dans le monde (GDD diapo 9 : « il l'accompagne ») : l'illustration de son
/// plus bel exemplaire (teinte et finition de la variante), qui suit l'explorateur en sautillant.
/// PROVISOIRE : purement visuel, il ne se bat pas et traverse tout (le boost reste son seul effet).
class CompanionComponent extends PositionComponent with HasGameReference<CollectearGame> {
  CompanionComponent(this.inst, Vector2 start)
      : follower = CompanionFollower(start.x, start.y),
        super(position: start.clone(), size: Vector2.all(24), anchor: Anchor.center, priority: 99);

  final CardInstance inst;
  final CompanionFollower follower;
  late final double _height = companionHeight(inst);
  Image? _art;
  double _t = 0;

  /// Les illustrations des cartes sont dans assets/cards (le cache de Flame lit assets/images par défaut).
  static final Images _cards = Images(prefix: 'assets/');

  late final Paint _artPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = ColorFilter.matrix(variantMatrix(inst.variant));
  static final Paint _shadow = Paint()..color = const Color(0x44000000);
  late final Paint _fallback = Paint()..color = Color(inst.card.rarity.color);
  static final Paint _outline = Paint()
    ..color = const Color(0xFF1B1440)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _sparkle = Paint()..color = const Color(0xFFFFFFFF);

  @override
  Future<void> onLoad() async {
    if (!Illustrations.available.contains(inst.card.id)) return;
    try {
      _art = await _cards.load(Illustrations.path(inst.card.id).replaceFirst('assets/', ''));
    } catch (e) {
      debugPrint('Compagnon : illustration ${inst.card.id} introuvable ($e)');
    }
  }

  void celebrate() => follower.celebrate();

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!game.started) return; // immobile pendant le compte à rebours
    final p = game.player;
    follower.update(dt, p.position.x, p.position.y, p.facing.x, p.facing.y);
    position.setValues(follower.x, follower.y);
    // Dessiné devant le joueur quand il est plus bas que lui à l'écran, derrière sinon.
    final wanted = follower.y > p.position.y ? 101 : 99;
    if (priority != wanted) priority = wanted;
  }

  @override
  void render(Canvas canvas) {
    final foot = Offset(size.x / 2, size.y / 2 + 8);
    final lift = follower.hop(_t);
    final h = _height;
    canvas.drawOval(Rect.fromCenter(center: foot, width: h * 0.55 - lift * 0.3, height: h * 0.18), _shadow);
    final img = _art;
    if (img == null) {
      final c = foot - Offset(0, h * 0.4 + lift);
      canvas.drawCircle(c, h * 0.3, _fallback);
      canvas.drawCircle(c, h * 0.3, _outline);
      return;
    }
    // L'illustration est un carré dont le dessin tient dans le cercle inscrit : on la pose un peu
    // plus bas que son bord pour que les pieds touchent l'ombre.
    final top = foot.dy - h - lift + h * 0.08;
    final dst = Rect.fromLTWH(foot.dx - h / 2, top, h, h);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    if (follower.facingLeft) {
      canvas.save();
      canvas.translate(foot.dx * 2, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(img, src, dst, _artPaint);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, dst, _artPaint);
    }
    // Exemplaire rare (3 ★ ou plus) : petites étincelles qui scintillent autour de lui.
    if (inst.variant.stars >= 3) {
      for (var i = 0; i < 3; i++) {
        final a = _t * 1.6 + i * 2.1;
        final tw = (math.sin(_t * 5 + i * 1.7) + 1) / 2;
        if (tw < 0.35) continue;
        final c = Offset(foot.dx + math.cos(a) * h * 0.45, top + h * 0.45 + math.sin(a) * h * 0.35);
        _star(canvas, c, 1.5 + tw * 2);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 2)
      ..lineTo(c.dx + r * 0.5, c.dy - r * 0.5)
      ..lineTo(c.dx + r * 2, c.dy)
      ..lineTo(c.dx + r * 0.5, c.dy + r * 0.5)
      ..lineTo(c.dx, c.dy + r * 2)
      ..lineTo(c.dx - r * 0.5, c.dy + r * 0.5)
      ..lineTo(c.dx - r * 2, c.dy)
      ..lineTo(c.dx - r * 0.5, c.dy - r * 0.5)
      ..close();
    canvas.drawPath(path, _sparkle);
  }
}
