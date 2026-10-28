import 'package:flutter/material.dart';

import '../../app_data.dart';
import '../../core/cards.dart';
import '../../core/variants.dart';
import '../card_detail_screen.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Filter { all, owned, creatures, heroes }

/// Onglet Bestiaire : les 300 cartes, possédées ou en silhouette.
class BestiaryTab extends StatefulWidget {
  const BestiaryTab({super.key, required this.data, required this.onChanged});
  final AppData data;
  final VoidCallback onChanged;

  @override
  State<BestiaryTab> createState() => _BestiaryTabState();
}

class _BestiaryTabState extends State<BestiaryTab> {
  _Filter _filter = _Filter.all;
  Rarity? _rarity;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final owned = data.collection.owned;
    final cards = data.pool.cards.where((c) {
      if (_rarity != null && c.rarity != _rarity) return false;
      return switch (_filter) {
        _Filter.all => true,
        _Filter.owned => owned.containsKey(c.id),
        _Filter.creatures => c.family == CardFamily.creature,
        _Filter.heroes => c.family == CardFamily.hero,
      };
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final r in Rarity.values) _RarityCounter(
                rarity: r,
                owned: data.pool.cards.where((c) => c.rarity == r && owned.containsKey(c.id)).length,
                total: data.pool.cards.where((c) => c.rarity == r).length,
                selected: _rarity == r,
                onTap: () => setState(() => _rarity = _rarity == r ? null : r),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(const ['Toutes', 'Possédées', 'Créatures', 'Héros'][f.index]),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              childAspectRatio: 0.72,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final c = cards[i];
              final qty = owned[c.id];
              final seeds = data.collection.variants[c.id] ?? const <int>[];
              CardInstance? best;
              for (final s in seeds) {
                final inst = CardInstance(c, s);
                if (best == null || inst.variant.stars > best.variant.stars) best = inst;
              }
              return CardView(
                card: c,
                instance: best,
                owned: qty != null,
                quantity: qty,
                favorite: qty != null && data.collection.favoriteCount(c.id) > 0,
                onTap: qty == null
                    ? null
                    : () => openCardDetail(
                          context,
                          c,
                          variantSeeds: seeds,
                          canFavorite: true,
                          isCompanion: data.collection.companionId == c.id,
                          onEquip: () async {
                            await data.collection.setCompanion(c.id);
                            widget.onChanged();
                          },
                        ).then((_) => widget.onChanged()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RarityCounter extends StatelessWidget {
  const _RarityCounter({
    required this.rarity,
    required this.owned,
    required this.total,
    required this.selected,
    required this.onTap,
  });
  final Rarity rarity;
  final int owned;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(rarity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(rarity.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          Text('$owned / $total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}
