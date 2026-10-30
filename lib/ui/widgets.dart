import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../core/cards.dart';
import '../core/cosmetics.dart';
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
    this.frame,
    this.onTap,
  });
  final GameCard card;

  /// Cadre acheté en Boutique (cartes de SA collection seulement) ; null ou Classique = bord blanc.
  final CardFrame? frame;

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
          final f = owned && frame != null && !frame!.isDefault ? frame : null;
          final body = Container(
            decoration: BoxDecoration(
              gradient: owned ? rarityGradient(rarity) : null,
              color: owned ? null : const Color(0xFF241A4D),
              borderRadius: BorderRadius.circular(f != null ? w * 0.055 : w * 0.08),
              border: f != null
                  ? null
                  : Border.all(color: owned ? Colors.white.withValues(alpha: 0.85) : Colors.white12, width: 2),
              boxShadow: owned && f == null
                  ? [BoxShadow(color: rarityColor(rarity).withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 3))]
                  : null,
            ),
            // Avec un cadre, son épaisseur remplace une partie de la marge : le contenu garde sa place.
            padding: EdgeInsets.all(f != null ? w * 0.018 : w * 0.05),
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
          if (f == null) return body;
          return CardFrameBorder(frame: f, width: w, child: body);
        }),
      ),
    );
  }
}

/// Bord d'une carte dessiné avec un cadre de la Boutique (dégradé en biais ou irisé tout autour).
class CardFrameBorder extends StatelessWidget {
  const CardFrameBorder({super.key, required this.frame, required this.width, required this.child});
  final CardFrame frame;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = [for (final c in frame.colors) Color(c)];
    final Gradient g = frame.sweep
        ? SweepGradient(colors: colors)
        : LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
    return Container(
      padding: EdgeInsets.all(math.max(3.0, width * 0.035)),
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: BorderRadius.circular(width * 0.08),
        border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1),
        boxShadow: [BoxShadow(color: colors[colors.length ~/ 2].withValues(alpha: 0.55), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
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
    // Semantics : bouton annoncé par les lecteurs d'écran, et trouvable par le test web de la CI.
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
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

/// Illustration d'un exemplaire : pastille teintée, motif, finition et éclat shiny.
/// Retour de Clem du 28/10 : effets plus visibles (motifs plus marqués, cadre, reflets animés).
/// [animate] : reflets et scintillements animés (grandes vignettes ; coupé dans les grilles).
class VariantEmblem extends StatefulWidget {
  const VariantEmblem({super.key, required this.card, required this.variant, required this.size, bool? animate})
      : animate = animate ?? size >= 120;
  final GameCard card;
  final Variant variant;
  final double size;
  final bool animate;

  @override
  State<VariantEmblem> createState() => _VariantEmblemState();
}

class _VariantEmblemState extends State<VariantEmblem> with SingleTickerProviderStateMixin {
  AnimationController? _anim;

  bool get _special =>
      widget.variant.shiny ||
      widget.variant.finish != VariantFinish.normal ||
      widget.variant.pattern == VariantPattern.stars ||
      widget.variant.pattern == VariantPattern.rings;

  @override
  void initState() {
    super.initState();
    if (widget.animate && _special) {
      _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    }
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  List<Color> get _colors {
    final v = widget.variant;
    return switch (v.finish) {
      VariantFinish.golden => const [Color(0xFFFFF4B8), Color(0xFFFFC93C), Color(0xFFB87A00)],
      VariantFinish.crystal => const [Color(0xFFFFFFFF), Color(0xFFBDEBFF), Color(0xFF5BB8F0)],
      VariantFinish.shadow => const [Color(0xFF6A54A8), Color(0xFF2A1B52), Color(0xFF0B0618)],
      VariantFinish.normal => [
          HSVColor.fromAHSV(1, v.hue, 0.40, 0.98).toColor(),
          HSVColor.fromAHSV(1, (v.hue + 20) % 360, 0.62, 0.82).toColor(),
          HSVColor.fromAHSV(1, (v.hue + 40) % 360, 0.80, 0.58).toColor(),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final v = widget.variant;
    final size = widget.size;
    final art = Center(
      child: Illustrations.available.contains(card.id)
          ? Padding(
              padding: EdgeInsets.all(size * 0.05),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(variantMatrix(v)),
                child: Image.asset(Illustrations.path(card.id), fit: BoxFit.contain),
              ),
            )
          : Icon(
              card.family == CardFamily.hero ? Icons.person : Icons.pets,
              size: size * 0.5,
              color: v.finish == VariantFinish.shadow ? const Color(0xFFCBB8FF) : Colors.white,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
    );
    Widget layer(double t) => Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: _EmblemPainter(variant: v, colors: _colors, t: t, front: false)),
          art,
          // Reflets, éclats et cadre par-dessus l'illustration.
          IgnorePointer(child: CustomPaint(painter: _EmblemPainter(variant: v, colors: _colors, t: t, front: true))),
        ]);
    final anim = _anim;
    return SizedBox(
      width: size,
      height: size,
      child: anim == null ? layer(0.15) : AnimatedBuilder(animation: anim, builder: (_, __) => layer(anim.value)),
    );
  }
}

/// Dessin d'un exemplaire. [front] = false : fond (aura, disque, motif) ; true : par-dessus
/// l'illustration (reflet des finitions, cadre arc-en-ciel et éclats du shiny, cadre des finitions).
/// [t] : temps de l'animation, de 0 à 1 (boucle).
class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.variant, required this.colors, required this.t, required this.front});
  final Variant variant;
  final List<Color> colors;
  final double t;
  final bool front;

  static const _rainbow = [
    Color(0xFFFF6B6B), Color(0xFFFFB627), Color(0xFF6BE36B), Color(0xFF4DD6FF), Color(0xFFB57BFF), Color(0xFFFF6B6B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.94; // marge pour l'aura et les éclats
    final rect = Rect.fromCircle(center: c, radius: r);
    if (front) {
      _front(canvas, c, r, rect);
    } else {
      _back(canvas, c, r, rect);
    }
  }

  void _back(Canvas canvas, Offset c, double r, Rect rect) {
    final finish = variant.finish;
    // Aura autour du disque : dorée, glacée ou violette (pulse avec l'animation).
    if (finish != VariantFinish.normal || variant.shiny) {
      final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      final glow = switch (finish) {
        VariantFinish.golden => const Color(0xFFFFC93C),
        VariantFinish.crystal => const Color(0xFF9BE3FF),
        VariantFinish.shadow => const Color(0xFF8E4DFF),
        VariantFinish.normal => const Color(0xFFFFFFFF),
      };
      canvas.drawCircle(
        c,
        r * (0.98 + 0.03 * pulse),
        Paint()
          ..color = glow.withValues(alpha: finish == VariantFinish.shadow ? 0.75 : 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, r * (0.10 + 0.05 * pulse)),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: colors, stops: const [0, 0.6, 1], center: const Alignment(-0.3, -0.35))
            .createShader(rect),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    if (finish == VariantFinish.crystal) _facets(canvas, c, r);
    if (finish == VariantFinish.shadow) _smoke(canvas, c, r);
    _pattern(canvas, c, r);
    canvas.restore();
  }

  /// Motif bien visible : clair et sombre en alternance, éléments plus grands qu'avant.
  void _pattern(Canvas canvas, Offset c, double r) {
    final light = Paint()..color = Colors.white.withValues(alpha: 0.42);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.16);
    switch (variant.pattern) {
      case VariantPattern.none:
        break;
      case VariantPattern.stripes:
        for (var i = -5; i <= 5; i++) {
          final o = i * r * 0.32;
          final p = (i.isEven ? light : dark)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14;
          canvas.drawLine(Offset(c.dx + o - r, c.dy - r), Offset(c.dx + o + r, c.dy + r), p);
        }
      case VariantPattern.spots:
        const spots = [
          (-0.55, -0.45, 0.20), (0.5, -0.4, 0.15), (-0.3, 0.55, 0.17), (0.55, 0.45, 0.22), (0.0, -0.75, 0.12),
          (-0.8, 0.1, 0.13), (0.82, 0.02, 0.11), (0.15, 0.82, 0.12), (-0.05, 0.0, 0.10),
        ];
        for (final (x, y, s) in spots) {
          canvas.drawCircle(c + Offset(x * r, y * r), r * s, light);
          canvas.drawCircle(c + Offset(x * r + r * s * 0.25, y * r + r * s * 0.25), r * s * 0.45, dark);
        }
      case VariantPattern.rings:
        // Anneaux concentriques qui s'élargissent lentement (ondes).
        for (var k = 0; k < 4; k++) {
          final f = ((k + t) / 4) % 1.0;
          canvas.drawCircle(
            c,
            r * (0.2 + 0.85 * f),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.09
              ..color = Colors.white.withValues(alpha: 0.5 * (1 - f) + 0.1),
          );
        }
      case VariantPattern.stars:
        // Étoiles qui tournent autour du personnage.
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4 + t * 2 * math.pi / 8;
          final rr = k.isEven ? 0.72 : 0.5;
          _star(canvas, c + Offset(math.cos(a) * r * rr, math.sin(a) * r * rr), r * (k.isEven ? 0.17 : 0.11),
              Colors.white.withValues(alpha: 0.55));
        }
    }
  }

  void _facets(Canvas canvas, Offset c, double r) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.28);
    final q = Paint()..color = const Color(0xFF2F8FD0).withValues(alpha: 0.18);
    for (var k = 0; k < 8; k++) {
      final a1 = k * math.pi / 4, a2 = a1 + math.pi / 4;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a1) * r * 1.2, c.dy + math.sin(a1) * r * 1.2)
        ..lineTo(c.dx + math.cos(a2) * r * 1.2, c.dy + math.sin(a2) * r * 1.2)
        ..close();
      canvas.drawPath(path, k.isEven ? p : q);
    }
  }

  void _smoke(Canvas canvas, Offset c, double r) {
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5 + t * 2 * math.pi;
      canvas.drawCircle(
        c + Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55),
        r * 0.38,
        Paint()
          ..color = const Color(0xFF8E4DFF).withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
      );
    }
  }

  void _front(Canvas canvas, Offset c, double r, Rect rect) {
    final finish = variant.finish;
    if (finish != VariantFinish.normal) {
      // Reflet qui balaie la carte en diagonale.
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      final x = -1.6 + 3.2 * t;
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment(x - 0.5, -1),
            end: Alignment(x + 0.5, 1),
            colors: [Colors.transparent, Colors.white.withValues(alpha: finish == VariantFinish.shadow ? 0.18 : 0.45),
              Colors.transparent],
          ).createShader(rect),
      );
      canvas.restore();
      // Cadre métallique (or), givré (cristal) ou sombre (ombre).
      final frame = switch (finish) {
        VariantFinish.golden => const [Color(0xFFFFF4B8), Color(0xFFB87A00), Color(0xFFFFE07A), Color(0xFF8A5A00), Color(0xFFFFF4B8)],
        VariantFinish.crystal => const [Color(0xFFFFFFFF), Color(0xFF7FD3FF), Color(0xFFFFFFFF), Color(0xFF4DA6E0), Color(0xFFFFFFFF)],
        _ => const [Color(0xFF8E4DFF), Color(0xFF1A0B33), Color(0xFFB57BFF), Color(0xFF1A0B33), Color(0xFF8E4DFF)],
      };
      canvas.drawCircle(
        c,
        r - r * 0.035,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..shader = SweepGradient(colors: frame, transform: GradientRotation(t * 2 * math.pi)).createShader(rect),
      );
    }
    if (variant.shiny) {
      canvas.drawCircle(
        c,
        r - r * (finish == VariantFinish.normal ? 0.03 : 0.11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.055
          ..shader = SweepGradient(colors: _rainbow, transform: GradientRotation(t * 2 * math.pi)).createShader(rect),
      );
      // Éclats qui scintillent à tour de rôle.
      const spots = [(0.72, -0.72, 0.20), (-0.78, 0.55, 0.14), (0.85, 0.35, 0.10), (-0.55, -0.85, 0.11)];
      for (var i = 0; i < spots.length; i++) {
        final (x, y, s) = spots[i];
        final tw = 0.55 + 0.45 * math.sin((t + i / spots.length) * 2 * math.pi);
        _star(canvas, c + Offset(x * r, y * r), r * s * tw, Colors.white);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double s, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? s : s * 0.38;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.t != t || old.variant.seed != variant.seed || old.front != front;
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

/// Champ de recherche de cartes par nom ou numéro (bestiaire, échanges, profil d'un ami).
/// Renvoie le texte tapé à chaque frappe ; la croix efface la recherche.
class CardSearchField extends StatefulWidget {
  const CardSearchField({super.key, required this.onChanged, this.hint = 'Rechercher une carte (nom ou n°)'});
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<CardSearchField> createState() => _CardSearchFieldState();
}

class _CardSearchFieldState extends State<CardSearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autocorrect: false,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.white),
      onChanged: (v) {
        setState(() {}); // affiche ou cache la croix
        widget.onChanged(v);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () {
                  _ctrl.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

/// Puces de rareté : toucher une rareté n'affiche qu'elle, la retoucher les remet toutes.
/// [counts] : nombre de cartes de chaque rareté dans la liste (affiché sur la puce), facultatif.
class RarityFilterChips extends StatelessWidget {
  const RarityFilterChips({super.key, required this.selected, required this.onChanged, this.counts});
  final Rarity? selected;
  final ValueChanged<Rarity?> onChanged;
  final Map<Rarity, int>? counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final r in Rarity.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(counts == null ? r.label : '${r.label} (${counts![r] ?? 0})'),
              labelStyle: TextStyle(
                color: selected == r ? Colors.white : rarityColor(r),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              selectedColor: rarityColor(r).withValues(alpha: 0.55),
              backgroundColor: Colors.black.withValues(alpha: 0.25),
              side: BorderSide(color: rarityColor(r)),
              showCheckmark: false,
              selected: selected == r,
              onSelected: (_) => onChanged(selected == r ? null : r),
            ),
          ),
      ]),
    );
  }
}
