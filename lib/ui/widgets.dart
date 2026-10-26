import 'package:flutter/material.dart';

import '../core/cards.dart';
import 'theme.dart';

IconData boostIcon(Boost b) => const [Icons.bolt, Icons.directions_run, Icons.shield, Icons.timer][b.index];

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
  const CardView({super.key, required this.card, this.owned = true, this.quantity, this.isNew = false, this.onTap});
  final GameCard card;
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
                        child: Container(
                          width: w * 0.55,
                          height: w * 0.55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: owned ? Colors.black.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                          ),
                          child: Icon(
                            owned ? (card.family == CardFamily.hero ? Icons.person : Icons.pets) : Icons.question_mark,
                            size: w * 0.32,
                            color: owned ? Colors.white : Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    if (owned && !small)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MiniStat(icon: Icons.favorite, value: card.hp),
                          _MiniStat(icon: Icons.flash_on, value: card.atk),
                          _MiniStat(icon: Icons.shield_outlined, value: card.def),
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
                if (isNew)
                  const Positioned(bottom: 18, left: 0, right: 0, child: Center(child: _Badge(text: 'NOUVEAU', color: AppColors.gold, dark: true))),
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

/// Fiche détaillée d'une carte (bottom sheet).
Future<void> showCardDetail(BuildContext context, GameCard card,
    {int? quantity, bool isCompanion = false, VoidCallback? onEquip}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 180, child: CardView(card: card, quantity: quantity)),
            const SizedBox(height: 12),
            Text('${card.rarity.label} · ${card.family == CardFamily.hero ? 'Héros' : 'Créature'}',
                style: TextStyle(color: rarityColor(card.rarity), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(boostIcon(card.boost), color: AppColors.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Boost ${card.boost.label} : ${card.boost.description}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ]),
            if (quantity != null) ...[
              const SizedBox(height: 4),
              Text('Exemplaires : $quantity', style: const TextStyle(color: Colors.white60)),
            ],
            if (onEquip != null) ...[
              const SizedBox(height: 16),
              ChunkyButton(
                label: isCompanion ? 'Déjà équipé' : 'Équiper comme compagnon',
                fontSize: 16,
                onPressed: isCompanion
                    ? null
                    : () {
                        onEquip();
                        Navigator.pop(ctx);
                      },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
