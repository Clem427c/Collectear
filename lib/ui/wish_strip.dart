import 'package:flutter/material.dart';

import '../core/cards.dart';
import 'widgets.dart';

/// Une carte de liste de souhaits, avec une petite étiquette dessous (« Tu en as 2 », « Retirer »…).
class WishItem {
  const WishItem(this.card, this.label, this.color);
  final GameCard card;
  final String label;
  final Color color;
}

/// Bandeau horizontal de cartes souhaitées (ma liste dans Social, celle d'un ami sur son profil).
class WishStrip extends StatelessWidget {
  const WishStrip({super.key, required this.items, required this.onTap});
  final List<WishItem> items;
  final void Function(GameCard card) onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final it = items[i];
            return SizedBox(
              width: 92,
              child: Column(children: [
                Expanded(child: CardView(card: it.card, onTap: () => onTap(it.card))),
                const SizedBox(height: 3),
                Text(it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: it.color, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            );
          },
        ),
      );
}
