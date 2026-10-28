import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app_data.dart';
import '../core/cards.dart';
import '../core/variants.dart';
import 'card_detail_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Galerie des variantes (depuis le Guide) : une carte montrée dans ses 10 apparences
/// (5 motifs, Shiny, Dorée, Cristal, Ombre, Dorée Shiny). Rien n'est ajouté à la collection.
class VariantGalleryScreen extends StatelessWidget {
  const VariantGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: rootBundle.loadString('assets/data/cards.json'),
        builder: (context, snap) => snap.hasData
            ? _Gallery(pool: CardPool.fromJsonString(snap.data!))
            : const Scaffold(backgroundColor: AppColors.ink, body: Center(child: CircularProgressIndicator())),
      );
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.pool});
  final CardPool pool;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final List<GameCard> _cards = [
    for (final c in widget.pool.cards)
      if (Illustrations.available.isEmpty || Illustrations.available.contains(c.id)) c,
  ];
  int _i = 0;

  GameCard get _card => _cards[_i];

  /// Seeds différentes pour chaque carte (comme dans le jeu, la teinte change d'une carte à l'autre).
  Map<ShowcaseKind, int> get _seeds => showcaseSeeds(start: _card.id * 100000);

  void _move(int d) => setState(() => _i = (_i + d) % _cards.length);

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final seeds = _seeds;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Toutes les variantes', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Carte précédente',
            onPressed: () => _move(-1),
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
          ),
          Expanded(
            child: Column(children: [
              Text(card.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('${card.rarity.label} · N° ${card.id.toString().padLeft(3, '0')}',
                  style: TextStyle(color: rarityColor(card.rarity), fontSize: 12)),
            ]),
          ),
          IconButton(
            tooltip: 'Carte suivante',
            onPressed: () => _move(1),
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Aperçu : ces exemplaires ne sont pas dans ta collection. Touche-en un pour le voir en grand.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              childAspectRatio: 0.82,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: ShowcaseKind.values.length,
            itemBuilder: (_, i) {
              final kind = ShowcaseKind.values[i];
              final seed = seeds[kind]!;
              final v = Variant.fromSeed(seed);
              return GestureDetector(
                onTap: () => openCardDetail(context, card,
                    variantSeeds: [for (final k in ShowcaseKind.values) seeds[k]!], initialSeed: seed),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, box) => Center(
                          child: VariantEmblem(
                              card: card, variant: v, size: box.biggest.shortestSide * 0.92, animate: true),
                        ),
                      ),
                    ),
                    Text(kind.label,
                        style: TextStyle(
                            color: v.stars >= 3 ? AppColors.gold : Colors.white, fontWeight: FontWeight.w900)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var s = 1; s <= 5; s++)
                        Icon(s <= v.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 14, color: AppColors.gold),
                    ]),
                    const SizedBox(height: 6),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
