import 'package:flutter/material.dart';

import '../../app_data.dart';
import '../../core/cards.dart';
import '../theme.dart';
import '../widgets.dart';

/// Amis fictifs pour le prototype (remplacés par les vrais amis à l'étape « En ligne »).
class _Friend {
  const _Friend(this.name, this.cards, this.color, this.online);
  final String name;
  final int cards;
  final Color color;
  final bool online;
}

const _exampleFriends = [
  _Friend('Explo_Mila', 87, Color(0xFF2EC4B6), true),
  _Friend('TomLeRapide', 142, Color(0xFFFF6B6B), false),
  _Friend('Nyx', 210, Color(0xFF7B5CFF), true),
];

const _onlineNote = 'Prototype : nécessite le mode en ligne (étape 3, Supabase).';

/// Onglet Social : amis, échanges, combats (prototype hors ligne).
class SocialTab extends StatelessWidget {
  const SocialTab({super.key, required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.w900),
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Amis'),
              Tab(icon: Icon(Icons.swap_horiz), text: 'Échanges'),
              Tab(icon: Icon(Icons.sports_martial_arts), text: 'Combats'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _FriendsView(data: data),
              _TradesView(data: data),
              _BattlesView(data: data),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PrototypeBanner extends StatelessWidget {
  const _PrototypeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: const Row(children: [
        Icon(Icons.construction, color: AppColors.gold, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text('Aperçu : les amis et données ci-dessous sont des exemples.',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- Amis

class _FriendsView extends StatelessWidget {
  const _FriendsView({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _PrototypeBanner(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF3A2D86), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mon code ami', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Row(children: [
              Text(data.collection.friendCode,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
              const Spacer(),
              IconButton(
                onPressed: () => showPrototypeSnack(context, _onlineNote),
                icon: const Icon(Icons.share, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Code ami à ajouter',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ChunkyButton(
                label: 'Ajouter',
                fontSize: 14,
                onPressed: () => showPrototypeSnack(context, _onlineNote),
              ),
            ]),
          ]),
        ),
        const SectionTitle('Mes amis'),
        for (final f in _exampleFriends) _FriendRow(friend: f),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});
  final _Friend friend;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3A2D86),
      child: ListTile(
        leading: Stack(children: [
          CircleAvatar(backgroundColor: friend.color, child: Text(friend.name[0], style: const TextStyle(color: Colors.white))),
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(radius: 6, backgroundColor: friend.online ? Colors.greenAccent : Colors.grey),
          ),
        ]),
        title: Text(friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('${friend.cards} / 300 cartes', style: const TextStyle(color: Colors.white60)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Échanger',
            onPressed: () => showPrototypeSnack(context, _onlineNote),
            icon: const Icon(Icons.swap_horiz, color: AppColors.teal),
          ),
          IconButton(
            tooltip: 'Défier',
            onPressed: () => showPrototypeSnack(context, _onlineNote),
            icon: const Icon(Icons.sports_martial_arts, color: AppColors.coral),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------- Échanges

class _TradesView extends StatefulWidget {
  const _TradesView({required this.data});
  final AppData data;

  @override
  State<_TradesView> createState() => _TradesViewState();
}

class _TradesViewState extends State<_TradesView> {
  _Friend _friend = _exampleFriends.first;
  GameCard? _give;
  GameCard? _get;

  Future<GameCard?> _pick(List<GameCard> cards, String title) {
    return showModalBottomSheet<GameCard>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: cards.isEmpty
                  ? const Center(
                      child: Text('Aucune carte disponible.\nLes doublons servent aux échanges.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 120,
                        childAspectRatio: 0.72,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, i) => CardView(card: cards[i], onTap: () => Navigator.pop(ctx, cards[i])),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // Je peux échanger mes cartes possédées ; l'ami « possède » une sélection d'exemple.
    final mine = data.ownedCards;
    final theirs = data.pool.cards.where((c) => (c.id * 7 + _friend.cards) % 5 == 0).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _PrototypeBanner(),
        const SectionTitle('Proposer un échange'),
        DropdownButtonFormField<_Friend>(
          value: _friend,
          decoration: const InputDecoration(labelText: 'Avec', border: OutlineInputBorder()),
          items: [for (final f in _exampleFriends) DropdownMenuItem(value: f, child: Text(f.name))],
          onChanged: (f) => setState(() {
            _friend = f ?? _friend;
            _get = null;
          }),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: _TradeSlot(
              label: 'Je donne',
              card: _give,
              onTap: () async {
                final c = await _pick(mine, 'Carte à donner');
                if (c != null) setState(() => _give = c);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.swap_horiz, color: AppColors.gold, size: 36),
          ),
          Expanded(
            child: _TradeSlot(
              label: 'Je reçois',
              card: _get,
              onTap: () async {
                final c = await _pick(theirs, 'Carte de ${_friend.name}');
                if (c != null) setState(() => _get = c);
              },
            ),
          ),
        ]),
        if (_give != null && _get != null && _give!.rarity != _get!.rarity)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Règle prévue : échanges entre cartes de même rareté.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.coral, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        ChunkyButton(
          label: 'Envoyer la proposition',
          fontSize: 16,
          color: AppColors.teal,
          onPressed: _give != null && _get != null ? () => showPrototypeSnack(context, _onlineNote) : null,
        ),
        const SectionTitle('Propositions reçues'),
        _IncomingTrade(data: data),
      ],
    );
  }
}

class _TradeSlot extends StatelessWidget {
  const _TradeSlot({required this.label, required this.card, required this.onTap});
  final String label;
  final GameCard? card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      SizedBox(
        width: 120,
        child: card != null
            ? CardView(card: card!, onTap: onTap)
            : GestureDetector(
                onTap: onTap,
                child: AspectRatio(
                  aspectRatio: 0.72,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white38, size: 40),
                  ),
                ),
              ),
      ),
    ]);
  }
}

class _IncomingTrade extends StatelessWidget {
  const _IncomingTrade({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final cards = data.pool.cards;
    final give = cards[57];
    final get = cards[12];
    return Card(
      color: const Color(0xFF3A2D86),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nyx te propose :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 80, child: CardView(card: give)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, color: AppColors.gold),
            ),
            SizedBox(width: 80, child: CardView(card: get, owned: data.collection.owned.containsKey(get.id))),
            const Spacer(),
            Column(children: [
              IconButton.filled(
                onPressed: () => showPrototypeSnack(context, _onlineNote),
                icon: const Icon(Icons.check),
                style: IconButton.styleFrom(backgroundColor: Colors.green),
              ),
              IconButton.filled(
                onPressed: () => showPrototypeSnack(context, _onlineNote),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(backgroundColor: AppColors.coral),
              ),
            ]),
          ]),
          const SizedBox(height: 6),
          Text('Tu reçois ${give.name}, tu donnes ${get.name}.',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------------- Combats

class _BattlesView extends StatefulWidget {
  const _BattlesView({required this.data});
  final AppData data;

  @override
  State<_BattlesView> createState() => _BattlesViewState();
}

class _BattlesViewState extends State<_BattlesView> {
  static const _teamSize = 3;
  final List<GameCard> _team = [];

  @override
  Widget build(BuildContext context) {
    final owned = widget.data.ownedCards;
    final power = _team.fold<int>(0, (s, c) => s + c.hp ~/ 5 + c.atk + c.def);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _PrototypeBanner(),
        const Text(
          'Le format des combats est encore en réflexion. Cet écran sert à visualiser la composition d\'une équipe.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        SectionTitle('Mon équipe', trailing: Text('Puissance $power', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900))),
        Row(children: [
          for (var i = 0; i < _teamSize; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: i < _team.length
                    ? CardView(card: _team[i], onTap: () => setState(() => _team.removeAt(i)))
                    : AspectRatio(
                        aspectRatio: 0.72,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white24, fontSize: 28))),
                        ),
                      ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        ChunkyButton(
          label: 'Défier un ami',
          icon: Icons.sports_martial_arts,
          fontSize: 18,
          color: AppColors.coral,
          textColor: Colors.white,
          onPressed: _team.length == _teamSize ? () => showPrototypeSnack(context, _onlineNote) : null,
        ),
        const SectionTitle('Choisis 3 cartes'),
        if (owned.isEmpty)
          const Text('Gagne des cartes en run pour composer ton équipe.', style: TextStyle(color: Colors.white60))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              childAspectRatio: 0.72,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: owned.length,
            itemBuilder: (_, i) {
              final c = owned[i];
              final inTeam = _team.contains(c);
              return Opacity(
                opacity: inTeam ? 0.35 : 1,
                child: CardView(
                  card: c,
                  onTap: inTeam || _team.length >= _teamSize ? null : () => setState(() => _team.add(c)),
                ),
              );
            },
          ),
      ],
    );
  }
}
