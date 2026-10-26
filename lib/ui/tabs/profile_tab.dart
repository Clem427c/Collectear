import 'package:flutter/material.dart';

import '../../app_data.dart';
import '../../core/cards.dart';
import '../theme.dart';
import '../widgets.dart';

/// Onglet Profil d'explorateur : statistiques et progression par rareté.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final col = data.collection;
    final cards = data.pool.cards;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.violet,
            child: Icon(Icons.explore, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Explorateur', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('Code ami : ${col.friendCode}', style: const TextStyle(color: Colors.white60)),
            ]),
          ),
        ]),
        const SectionTitle('Statistiques'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _StatBox(icon: Icons.explore, label: 'Runs jouées', value: '${col.totalRuns}'),
            _StatBox(icon: Icons.sports_martial_arts, label: 'Ennemis vaincus', value: '${col.totalKills}'),
            _StatBox(icon: Icons.style, label: 'Cartes gagnées', value: '${col.totalCards}'),
            _StatBox(icon: Icons.emoji_events, label: 'Record de kills', value: '${col.bestKills}'),
          ],
        ),
        const SectionTitle('Bestiaire par rareté'),
        for (final r in Rarity.values.reversed)
          _RarityBar(
            rarity: r,
            owned: cards.where((c) => c.rarity == r && col.owned.containsKey(c.id)).length,
            total: cards.where((c) => c.rarity == r).length,
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF3A2D86), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: AppColors.gold, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _RarityBar extends StatelessWidget {
  const _RarityBar({required this.rarity, required this.owned, required this.total});
  final Rarity rarity;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(rarity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(rarity.label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$owned / $total', style: const TextStyle(color: Colors.white)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : owned / total,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}
