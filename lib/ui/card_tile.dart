import 'package:flutter/material.dart';

import '../core/cards.dart';
import 'theme.dart';

/// Ligne de carte (récap, bestiaire). Le visuel viendra avec les illustrations.
class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.card, this.isNew = false, this.quantity});
  final GameCard card;
  final bool isNew;
  final int? quantity;

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(card.rarity);
    return Card(
      color: AppColors.night,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(card.family == CardFamily.hero ? Icons.person : Icons.pets, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(card.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
                        child: const Text('NOUVEAU',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.ink)),
                      ),
                    ],
                  ]),
                  Text(
                    '${card.rarity.label} · ${card.family == CardFamily.hero ? 'Héros' : 'Créature'} · N° ${card.id.toString().padLeft(3, '0')}',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                  Text('PV ${card.hp} · ATQ ${card.atk} · DEF ${card.def} · Boost ${card.boost.label}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (quantity != null && quantity! > 1)
              Text('×$quantity', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
