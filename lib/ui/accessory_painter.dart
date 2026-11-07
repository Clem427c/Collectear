import 'dart:math' as math;
import 'dart:ui';

import '../core/cosmetics.dart';

/// Dessine l'accessoire du compagnon (GDD diapo 15), par le code, sans image.
/// Utilisé en run (compagnon dans le monde) et dans la Boutique (aperçu).
///
/// [head] : haut du dessin (où se pose l'accessoire), [size] : hauteur du compagnon,
/// [center] : milieu du corps (pour les lucioles), [t] : temps en secondes (animation).
void paintAccessory(Canvas canvas, Accessory acc, Offset head, double size, double t, {Offset? center}) {
  final s = size;
  switch (acc.style) {
    case AccessoryStyle.none:
      return;
    case AccessoryStyle.leaf:
      _leaf(canvas, acc, head, s, t);
    case AccessoryStyle.bow:
      _bow(canvas, acc, head, s);
    case AccessoryStyle.hat:
      _hat(canvas, acc, head, s);
    case AccessoryStyle.halo:
      _halo(canvas, acc, head, s, t);
    case AccessoryStyle.fireflies:
      _fireflies(canvas, acc, center ?? head + Offset(0, s * 0.4), s, t);
    case AccessoryStyle.crown:
      _crown(canvas, acc, head, s, t);
  }
}

final Paint _ink = Paint()
  ..color = const Color(0xFF1B1440)
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

Paint _fill(int argb) => Paint()..color = Color(argb);

Color _shade(int argb, double f) {
  final c = Color(argb);
  return Color.from(alpha: c.a, red: c.r * f, green: c.g * f, blue: c.b * f);
}

void _outline(Canvas canvas, Path path, double s) {
  _ink.strokeWidth = math.max(1, s * 0.035);
  canvas.drawPath(path, _ink);
}

/// Petite pousse : une tige et deux feuilles qui se balancent doucement.
void _leaf(Canvas canvas, Accessory acc, Offset head, double s, double t) {
  canvas.save();
  canvas.translate(head.dx, head.dy + s * 0.04);
  canvas.rotate(math.sin(t * 2.2) * 0.12);
  final stem = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(s * 0.02, -s * 0.1, 0, -s * 0.16);
  _ink.strokeWidth = math.max(1.5, s * 0.05);
  canvas.drawPath(stem, _ink);
  canvas.drawPath(stem, Paint()
    ..color = _shade(acc.color, 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, s * 0.025));
  for (final side in const [-1.0, 1.0]) {
    final leaf = Path()
      ..moveTo(0, -s * 0.15)
      ..quadraticBezierTo(side * s * 0.09, -s * 0.27, side * s * 0.2, -s * 0.2)
      ..quadraticBezierTo(side * s * 0.09, -s * 0.11, 0, -s * 0.15)
      ..close();
    canvas.drawPath(leaf, _fill(side < 0 ? acc.color : _shade(acc.color, 0.85).toARGB32()));
    _outline(canvas, leaf, s);
  }
  canvas.restore();
}

/// Nœud : deux boucles et un petit nœud central, posé sur le haut de la tête.
void _bow(Canvas canvas, Accessory acc, Offset head, double s) {
  final c = head + Offset(0, s * 0.03);
  final w = s * 0.17, h = s * 0.11;
  for (final side in const [-1.0, 1.0]) {
    final loop = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + side * w, c.dy - h)
      ..quadraticBezierTo(c.dx + side * w * 1.25, c.dy, c.dx + side * w, c.dy + h)
      ..close();
    canvas.drawPath(loop, _fill(acc.color));
    _outline(canvas, loop, s);
  }
  final knot = Rect.fromCenter(center: c, width: s * 0.08, height: s * 0.1);
  canvas.drawRRect(RRect.fromRectAndRadius(knot, Radius.circular(s * 0.02)), Paint()..color = _shade(acc.color, 0.8));
  _outline(canvas, Path()..addRRect(RRect.fromRectAndRadius(knot, Radius.circular(s * 0.02))), s);
}

/// Chapeau d'explorateur : large bord, calotte cabossée et ruban sombre.
void _hat(Canvas canvas, Accessory acc, Offset head, double s) {
  final base = head + Offset(0, s * 0.07);
  final brim = Rect.fromCenter(center: base, width: s * 0.56, height: s * 0.12);
  final crown = Path()
    ..moveTo(base.dx - s * 0.17, base.dy)
    ..lineTo(base.dx - s * 0.15, base.dy - s * 0.17)
    ..quadraticBezierTo(base.dx, base.dy - s * 0.12, base.dx + s * 0.15, base.dy - s * 0.17)
    ..lineTo(base.dx + s * 0.17, base.dy)
    ..close();
  canvas.drawOval(brim, Paint()..color = _shade(acc.color, 0.8));
  _outline(canvas, Path()..addOval(brim), s);
  canvas.drawPath(crown, _fill(acc.color));
  final band = Rect.fromLTRB(base.dx - s * 0.165, base.dy - s * 0.06, base.dx + s * 0.165, base.dy - s * 0.01);
  canvas.drawRect(band, Paint()..color = const Color(0xFF3B2416));
  _outline(canvas, crown, s);
}

/// Auréole : anneau doré qui flotte au-dessus de la tête et brille doucement.
void _halo(Canvas canvas, Accessory acc, Offset head, double s, double t) {
  final c = head + Offset(0, -s * 0.12 - math.sin(t * 2.4) * s * 0.03);
  final r = Rect.fromCenter(center: c, width: s * 0.42, height: s * 0.12);
  final glow = (math.sin(t * 3) + 1) / 2;
  canvas.drawOval(
      r.inflate(s * 0.03),
      Paint()
        ..color = Color(acc.color).withValues(alpha: 0.25 + glow * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09);
  canvas.drawOval(
      r,
      Paint()
        ..color = Color(acc.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.05));
}

/// Lucioles : trois petites lumières qui tournent autour du compagnon et clignotent.
void _fireflies(Canvas canvas, Accessory acc, Offset center, double s, double t) {
  for (var i = 0; i < 3; i++) {
    final a = t * 1.3 + i * (math.pi * 2 / 3);
    final p = center + Offset(math.cos(a) * s * 0.55, math.sin(a * 1.7) * s * 0.3 - s * 0.05);
    final tw = 0.55 + 0.45 * math.sin(t * 6 + i * 2.3);
    canvas.drawCircle(p, s * 0.09, Paint()..color = Color(acc.color).withValues(alpha: 0.3 * tw));
    canvas.drawCircle(p, s * 0.035, Paint()..color = Color(acc.color).withValues(alpha: 0.6 + 0.4 * tw));
  }
}

/// Couronne : trois pointes dorées et des pierres, avec un reflet qui passe.
void _crown(Canvas canvas, Accessory acc, Offset head, double s, double t) {
  final base = head + Offset(0, s * 0.05);
  final w = s * 0.17, h = s * 0.17;
  final path = Path()
    ..moveTo(base.dx - w, base.dy)
    ..lineTo(base.dx - w * 1.1, base.dy - h)
    ..lineTo(base.dx - w * 0.5, base.dy - h * 0.55)
    ..lineTo(base.dx, base.dy - h * 1.2)
    ..lineTo(base.dx + w * 0.5, base.dy - h * 0.55)
    ..lineTo(base.dx + w * 1.1, base.dy - h)
    ..lineTo(base.dx + w, base.dy)
    ..close();
  canvas.drawPath(path, _fill(acc.color));
  canvas.drawRect(Rect.fromLTRB(base.dx - w, base.dy - h * 0.28, base.dx + w, base.dy),
      Paint()..color = _shade(acc.color, 0.8));
  _outline(canvas, path, s);
  canvas.drawCircle(Offset(base.dx, base.dy - h * 0.14), s * 0.03, Paint()..color = const Color(0xFFE84A5F));
  for (final side in const [-1.0, 1.0]) {
    canvas.drawCircle(Offset(base.dx + side * w * 0.55, base.dy - h * 0.14), s * 0.022,
        Paint()..color = const Color(0xFF4DB8FF));
  }
  // Reflet qui passe toutes les ~3 s.
  final k = (t % 3) / 3;
  if (k < 0.3) {
    final x = base.dx - w + (k / 0.3) * 2 * w;
    canvas.drawLine(Offset(x, base.dy - h * 0.25), Offset(x + s * 0.04, base.dy - h * 0.9),
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..strokeWidth = math.max(1, s * 0.03)
          ..strokeCap = StrokeCap.round);
  }
}
