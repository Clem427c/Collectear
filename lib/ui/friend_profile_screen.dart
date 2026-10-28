import 'package:flutter/material.dart';

import '../app_data.dart';
import '../core/cards.dart';
import '../core/social.dart';
import '../core/variants.dart';
import '../online.dart';
import 'card_detail_screen.dart';
import 'theme.dart';
import 'widgets.dart';

const _panel = Color(0xFF3A2D86);

/// Profil d'un ami : sa progression par rareté et sa collection en détail, comparée à la mienne.
/// [onTrade] ouvre la composition d'un échange (avec la carte demandée, si on en a choisi une).
class FriendProfileScreen extends StatefulWidget {
  const FriendProfileScreen({
    super.key,
    required this.data,
    required this.friend,
    required this.onTrade,
    this.bestKills,
  });
  final AppData data;
  final Friend friend;
  final void Function(ServerCard? request) onTrade;

  /// Record d'ennemis vaincus en une run (classement), s'il est connu.
  final int? bestKills;

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  FriendCollection? _col;
  String? _error;
  FriendCardFilter _filter = FriendCardFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (cards, err) = await Online.cardsOf(widget.friend.userId);
    if (!mounted) return;
    setState(() {
      _error = err;
      _col = FriendCollection(cards ?? const [], widget.data.pool, widget.data.collection.owned);
    });
  }

  /// Exemplaires de l'ami pour une carte : on peut les regarder ou en demander un.
  void _openSpecies(GameCard card, List<ServerCard> copies) {
    final mine = widget.data.collection.owned[card.id] ?? 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              '${card.rarity.label} · ${widget.friend.name} en a ${copies.length} · '
              '${mine == 0 ? 'tu ne l\'as pas' : 'tu en as $mine'}',
              style: TextStyle(color: rarityColor(card.rarity), fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: copies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final sc = copies[i];
                  return SizedBox(
                    width: 110,
                    child: Column(children: [
                      Expanded(
                        child: CardView(
                          card: card,
                          instance: CardInstance(card, sc.seed),
                          onTap: () => openCardDetail(context, card,
                              variantSeeds: [for (final c in copies) c.seed], initialSeed: sc.seed),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onTrade(sc);
                        },
                        child: const Text('Demander', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  );
                },
              ),
            ),
            const Text('Touche une carte pour la voir en grand.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    final col = _col;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: Text(f.name),
        actions: [
          TextButton.icon(
            onPressed: () => widget.onTrade(null),
            icon: const Icon(Icons.swap_horiz, color: AppColors.teal),
            label: const Text('Échanger', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: col == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverList.list(children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_error!, style: const TextStyle(color: AppColors.coral)),
                      ),
                    _header(col),
                    const SectionTitle('Progression par rareté'),
                    _rarities(col),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, children: [
                      for (final flt in FriendCardFilter.values)
                        ChoiceChip(
                          label: Text(switch (flt) {
                            FriendCardFilter.all => '${flt.label} (${col.species})',
                            FriendCardFilter.iLack => '${flt.label} (${col.iLackCount})',
                            FriendCardFilter.duplicates => '${flt.label} (${col.cards(flt).length})',
                          }),
                          selected: _filter == flt,
                          onSelected: (_) => setState(() => _filter = flt),
                        ),
                    ]),
                    const SizedBox(height: 10),
                  ]),
                ),
                _grid(col),
              ]),
            ),
    );
  }

  Widget _header(FriendCollection col) {
    final f = widget.friend;
    final total = widget.data.pool.cards.length;
    const colors = [AppColors.teal, AppColors.coral, AppColors.violet, AppColors.gold];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors[f.name.hashCode.abs() % colors.length],
            child: Text(f.name.isEmpty ? '?' : f.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              if (f.code.isNotEmpty)
                Text('Code ami ${formatFriendCode(f.code)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _stat('${col.species} / $total', 'cartes'),
          _stat('${col.copies}', 'exemplaires'),
          if (widget.bestKills != null) _stat('${widget.bestKills}', 'record ennemis'),
        ]),
        const SizedBox(height: 10),
        Text(
          '${col.iLackCount} carte${col.iLackCount > 1 ? 's' : ''} qu\'il a et pas toi · '
          '${col.heLacksCount} que tu as et pas lui',
          style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      );

  Widget _rarities(FriendCollection col) {
    final by = col.byRarity;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        for (final r in Rarity.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 92,
                child: Text(r.label, style: TextStyle(color: rarityColor(r), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: by[r]!.$2 == 0 ? 0 : by[r]!.$1 / by[r]!.$2,
                    minHeight: 10,
                    color: rarityColor(r),
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text('${by[r]!.$1} / ${by[r]!.$2}',
                    textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _grid(FriendCollection col) {
    final cards = col.cards(_filter);
    final owned = widget.data.collection.owned;
    if (cards.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            switch (_filter) {
              FriendCardFilter.all => '${widget.friend.name} n\'a pas encore de cartes en ligne.',
              FriendCardFilter.iLack => 'Tu as déjà toutes ses cartes !',
              FriendCardFilter.duplicates => 'Pas de doublons pour l\'instant.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          childAspectRatio: 0.72,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final card = cards[i];
          final copies = col.bySpecies[card.id]!;
          return CardView(
            card: card,
            instance: CardInstance(card, copies.first.seed),
            quantity: copies.length,
            isNew: !owned.containsKey(card.id),
            onTap: () => _openSpecies(card, copies),
          );
        },
      ),
    );
  }
}
