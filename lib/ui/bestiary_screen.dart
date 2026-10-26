import 'package:flutter/material.dart';

import '../core/cards.dart';
import '../main.dart';
import 'card_tile.dart';
import 'theme.dart';

class BestiaryScreen extends StatelessWidget {
  const BestiaryScreen({super.key, required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final owned = data.collection.owned;
    final cards = data.pool.cards;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        title: Text('Bestiaire · ${owned.length} / ${cards.length}'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final c = cards[i];
          final qty = owned[c.id];
          if (qty != null) return CardTile(card: c, quantity: qty);
          return Card(
            color: AppColors.night.withValues(alpha: 0.5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: rarityColor(c.rarity).withValues(alpha: 0.35),
                child: const Text('?', style: TextStyle(color: Colors.white54)),
              ),
              title: const Text('???', style: TextStyle(color: Colors.white38)),
              subtitle: Text('N° ${c.id.toString().padLeft(3, '0')} · ${c.rarity.label}',
                  style: const TextStyle(color: Colors.white30)),
            ),
          );
        },
      ),
    );
  }
}
