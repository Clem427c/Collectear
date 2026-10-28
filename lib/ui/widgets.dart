import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../core/cards.dart';
import '../core/variants.dart';
import '../app_data.dart';
import 'theme.dart';

IconData boostIcon(Boost b) =>
    const [Icons.bolt, Icons.directions_run, Icons.shield, Icons.timer, Icons.open_in_full][b.index];

/// Dégradé de fond selon la rareté (style cartes de jeu mobile).
LinearGradient rarityGradient(Rarity r) {
  final c = rarityColor(r);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(c, Colors.white, 0.25)!, c, Color.lerp(c, Colors.black, 0.45)!],
  );
}

/// Carte portrait. Le visuel central sera remplacé par l'illustration.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.instance,
    this.owned = true,
    this.quantity,
    this.isNew = false,
    this.favorite = false,
    this.onTap,
  });
  final GameCard card;

  /// Exemplaire en favori : étoile dorée dans le coin (il ne peut pas être échangé).
  final bool favorite;

  /// Exemplaire précis (variante) ; null = vue de l'espèce.
  final CardInstance? instance;
  final bool owned;
  final int? quantity;
  final bool isNew;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = card.rarity;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final small = w < 110;
          return Container(
            decoration: BoxDecoration(
              gradient: owned ? rarityGradient(rarity) : null,
              color: owned ? null : const Color(0xFF241A4D),
              borderRadius: BorderRadius.circular(w * 0.08),
              border: Border.all(color: owned ? Colors.white.withValues(alpha: 0.85) : Colors.white12, width: 2),
              boxShadow: owned
                  ? [BoxShadow(color: rarityColor(rarity).withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 3))]
                  : null,
            ),
            padding: EdgeInsets.all(w * 0.05),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    Text(
                      owned ? card.name : '???',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: owned ? Colors.white : Colors.white30,
                        fontWeight: FontWeight.w900,
                        fontSize: small ? 10 : 13,
                        height: 1.1,
                        shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2)],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: instance != null
                            ? VariantEmblem(card: card, variant: instance!.variant, size: w * 0.6)
                            : Container(
                                width: w * 0.55,
                                height: w * 0.55,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: owned
                                      ? Colors.black.withValues(alpha: 0.18)
                                      : Colors.white.withValues(alpha: 0.04),
                                ),
                                child: owned && Illustrations.available.contains(card.id)
                                    ? Padding(
                                        padding: EdgeInsets.all(w * 0.03),
                                        child: Image.asset(Illustrations.path(card.id), fit: BoxFit.contain),
                                      )
                                    : Icon(
                                        owned
                                            ? (card.family == CardFamily.hero ? Icons.person : Icons.pets)
                                            : Icons.question_mark,
                                        size: w * 0.32,
                                        color: owned ? Colors.white : Colors.white24,
                                      ),
                              ),
                      ),
                    ),
                    if (instance != null && !small)
                      Text(instance!.variant.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: instance!.variant.prestige > 0 ? AppColors.gold : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          )),
                    if (owned && !small)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MiniStat(icon: Icons.favorite, value: instance?.hp ?? card.hp),
                          _MiniStat(icon: Icons.flash_on, value: instance?.atk ?? card.atk),
                          _MiniStat(icon: Icons.shield_outlined, value: instance?.def ?? card.def),
                        ],
                      ),
                    Text(
                      'N° ${card.id.toString().padLeft(3, '0')}',
                      style: TextStyle(color: owned ? Colors.white70 : Colors.white24, fontSize: small ? 8 : 10),
                    ),
                  ],
                ),
                if (owned)
                  Positioned(
                    top: w * 0.22,
                    right: 0,
                    child: CircleAvatar(
                      radius: small ? 9 : 12,
                      backgroundColor: AppColors.ink.withValues(alpha: 0.8),
                      child: Icon(boostIcon(card.boost), size: small ? 11 : 15, color: AppColors.gold),
                    ),
                  ),
                if (quantity != null && quantity! > 1)
                  Positioned(
                    top: w * 0.22,
                    left: 0,
                    child: _Badge(text: '×$quantity', color: AppColors.ink),
                  ),
                if (favorite)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Icon(Icons.star_rounded,
                        color: AppColors.gold,
                        size: small ? 16 : 22,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 3)]),
                  ),
                // Badge « Nouveau » collé dans le coin haut droit, comme un autocollant (ne cache aucun texte).
                if (isNew)
                  Positioned(
                    top: -w * 0.05 - 10,
                    right: -w * 0.05 - 10,
                    child: Transform.rotate(
                      angle: 0.2,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: _Badge(text: 'NOUVEAU', color: AppColors.gold, dark: true),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white),
      const SizedBox(width: 2),
      Text('$value', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.dark = false});
  final String text;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: dark ? AppColors.ink : Colors.white)),
    );
  }
}

/// Gros bouton « 3D » façon jeu mobile.
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.gold,
    this.textColor = AppColors.ink,
    this.fontSize = 22,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = enabled ? color : Colors.grey.shade700;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: fontSize * 0.7, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(base, Colors.white, 0.3)!, base],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color.lerp(base, Colors.black, 0.35)!, width: 2),
          boxShadow: [BoxShadow(color: Color.lerp(base, Colors.black, 0.5)!, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: textColor, size: fontSize), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: enabled ? textColor : Colors.white54, fontSize: fontSize, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titre de section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

void showPrototypeSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// Illustration provisoire d'une variante : pastille teintée, motif, finition et éclat shiny.
/// Sera remplacée par l'illustration IA teintée de la même façon.
class VariantEmblem extends StatelessWidget {
  const VariantEmblem({super.key, required this.card, required this.variant, required this.size});
  final GameCard card;
  final Variant variant;
  final double size;

  List<Color> get _colors => switch (variant.finish) {
        VariantFinish.golden => const [Color(0xFFFFF1A8), Color(0xFFE0A100)],
        VariantFinish.crystal => const [Color(0xFFF2FDFF), Color(0xFF7FD3FF)],
        VariantFinish.shadow => const [Color(0xFF5B4B8A), Color(0xFF120B26)],
        VariantFinish.normal => [
            HSVColor.fromAHSV(1, variant.hue, 0.45, 0.95).toColor(),
            HSVColor.fromAHSV(1, (variant.hue + 25) % 360, 0.75, 0.65).toColor(),
          ],
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmblemPainter(colors: _colors, pattern: variant.pattern, shiny: variant.shiny),
        child: Center(
          child: Illustrations.available.contains(card.id)
              ? Padding(
                  padding: EdgeInsets.all(size * 0.04),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(variantMatrix(variant)),
                    child: Image.asset(Illustrations.path(card.id), fit: BoxFit.contain),
                  ),
                )
              : Icon(
            card.family == CardFamily.hero ? Icons.person : Icons.pets,
            size: size * 0.5,
            color: variant.finish == VariantFinish.shadow ? const Color(0xFFCBB8FF) : Colors.white,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.colors, required this.pattern, required this.shiny});
  final List<Color> colors;
  final VariantPattern pattern;
  final bool shiny;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect));
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final p = Paint()..color = Colors.white.withValues(alpha: 0.22);
    switch (pattern) {
      case VariantPattern.none:
        break;
      case VariantPattern.stripes:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12;
        for (var i = -4; i <= 4; i++) {
          final o = i * r * 0.35;
          canvas.drawLine(Offset(c.dx + o - r, c.dy - r), Offset(c.dx + o + r, c.dy + r), p);
        }
      case VariantPattern.spots:
        for (final o in const [Offset(-0.5, -0.4), Offset(0.45, -0.3), Offset(-0.2, 0.5), Offset(0.5, 0.45), Offset(0.05, -0.05)]) {
          canvas.drawCircle(c + Offset(o.dx * r, o.dy * r), r * 0.16, p);
        }
      case VariantPattern.rings:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07;
        for (var k = 1; k <= 3; k++) {
          canvas.drawCircle(c, r * k * 0.3, p);
        }
      case VariantPattern.stars:
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3;
          _star(canvas, c + Offset(math.cos(a) * r * 0.62, math.sin(a) * r * 0.62), r * 0.13, p);
        }
    }
    canvas.restore();
    if (shiny) {
      canvas.drawCircle(
        c,
        r - 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = const SweepGradient(colors: [
            Color(0xFFFF6B6B), Color(0xFFFFB627), Color(0xFF6BE36B), Color(0xFF4DD6FF), Color(0xFFB57BFF), Color(0xFFFF6B6B),
          ]).createShader(rect),
      );
      final sp = Paint()..color = Colors.white;
      _star(canvas, c + Offset(r * 0.7, -r * 0.7), r * 0.18, sp);
      _star(canvas, c + Offset(-r * 0.75, r * 0.55), r * 0.12, sp);
    }
  }

  void _star(Canvas canvas, Offset c, double s, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? s : s * 0.4;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = p.color);
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.colors != colors || old.pattern != pattern || old.shiny != shiny;
}


/// Matrice de couleur appliquée à l'illustration d'une variante :
/// rotation de teinte (±70°) ou finition spéciale (dorée, cristal, ombre).
List<double> variantMatrix(Variant v) {
  switch (v.finish) {
    case VariantFinish.golden:
      return const [
        0.50, 0.45, 0.15, 0, 30, //
        0.40, 0.40, 0.12, 0, 15,
        0.15, 0.15, 0.08, 0, 0,
        0, 0, 0, 1, 0,
      ];
    case VariantFinish.crystal:
      return const [
        0.30, 0.40, 0.10, 0, 70, //
        0.30, 0.45, 0.10, 0, 95,
        0.30, 0.45, 0.20, 0, 120,
        0, 0, 0, 0.92, 0,
      ];
    case VariantFinish.shadow:
      return const [
        0.20, 0.25, 0.08, 0, 15, //
        0.12, 0.18, 0.06, 0, 0,
        0.25, 0.30, 0.20, 0, 35,
        0, 0, 0, 1, 0,
      ];
    case VariantFinish.normal:
      return hueRotation(((v.hue / 360) * 2 - 1) * 70);
  }
}

List<double> hueRotation(double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  const r = 0.213, g = 0.715, b = 0.072;
  return [
    r + c * (1 - r) - s * r, g - c * g - s * g, b - c * b + s * (1 - b), 0, 0, //
    r - c * r + s * 0.143, g + c * (1 - g) + s * 0.140, b - c * b - s * 0.283, 0, 0,
    r - c * r - s * (1 - r), g - c * g + s * g, b + c * (1 - b) + s * b, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
