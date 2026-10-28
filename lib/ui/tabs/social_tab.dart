import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_data.dart';
import '../../core/cards.dart';
import '../../core/social.dart';
import '../../core/variants.dart';
import '../../online.dart';
import '../account_panel.dart';
import '../theme.dart';
import '../widgets.dart';

const _onlineNote = 'Prototype : le format des combats reste à définir.';
const _panel = Color(0xFF3A2D86);

/// Amis et échanges chargés depuis le serveur, partagés par les onglets Amis et Échanges.
class _SocialModel extends ChangeNotifier {
  List<Friend> friends = [];
  List<Trade> trades = [];
  bool loading = false;
  String? error;

  List<Friend> get accepted => friends.where((f) => f.status == FriendStatus.friend).toList();
  int get pending => pendingActions(friends, trades);

  Future<void> refresh() async {
    if (Online.user == null || loading) return;
    loading = true;
    notifyListeners();
    final (f, e1) = await Online.listFriends();
    final (t, e2) = await Online.myTrades();
    friends = f ?? friends;
    trades = t ?? trades;
    error = e1 ?? e2;
    loading = false;
    notifyListeners();
  }
}

/// Onglet Social : amis (code ami), échanges carte contre carte, combats (prototype).
class SocialTab extends StatefulWidget {
  const SocialTab({super.key, required this.data});
  final AppData data;

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab> {
  final _model = _SocialModel();
  String? _lastUser;

  @override
  void initState() {
    super.initState();
    Online.revision.addListener(_onOnline);
    _onOnline();
  }

  /// Recharge à la connexion (ou au changement de compte).
  void _onOnline() {
    final u = Online.user?.id;
    if (u != _lastUser) {
      _lastUser = u;
      _model.friends = [];
      _model.trades = [];
      if (u != null) _model.refresh();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    Online.revision.removeListener(_onOnline);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          ListenableBuilder(
            listenable: _model,
            builder: (context, _) {
              final incomingFriends = _model.friends.where((f) => f.status == FriendStatus.incoming).length;
              final incomingTrades = _model.trades.where((t) => t.incoming && t.isPending).length;
              return TabBar(
                indicatorColor: AppColors.gold,
                labelColor: AppColors.gold,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                tabs: [
                  Tab(icon: _badge(Icons.people, incomingFriends), text: 'Amis'),
                  Tab(icon: _badge(Icons.swap_horiz, incomingTrades), text: 'Échanges'),
                  const Tab(icon: Icon(Icons.sports_martial_arts), text: 'Combats'),
                ],
              );
            },
          ),
          Expanded(
            child: TabBarView(children: [
              _Online(child: _FriendsView(data: widget.data, model: _model)),
              _Online(child: _TradesView(data: widget.data, model: _model)),
              _BattlesView(data: widget.data),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, int n) => Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        backgroundColor: AppColors.coral,
        child: Icon(icon),
      );
}

/// Affiche son contenu si le joueur est connecté, sinon le panneau de connexion.
class _Online extends StatelessWidget {
  const _Online({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Online.revision,
      builder: (context, _, __) {
        if (Online.user != null) return child;
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Amis et échanges',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Connecte-toi pour ajouter des amis avec leur code et échanger des cartes avec eux.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (Online.ready || Online.config.isUsable)
            const AccountPanel()
          else
            const Text('Le mode en ligne n\'est pas disponible dans cette version.',
                style: TextStyle(color: Colors.white60)),
        ]);
      },
    );
  }
}

void _snack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.coral : AppColors.night));
}

Widget _avatar(String name) {
  const colors = [AppColors.teal, AppColors.coral, AppColors.violet, AppColors.gold];
  return CircleAvatar(
    backgroundColor: colors[name.hashCode.abs() % colors.length],
    child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  );
}

// ----------------------------------------------------------------- Amis

class _FriendsView extends StatefulWidget {
  const _FriendsView({required this.data, required this.model});
  final AppData data;
  final _SocialModel model;

  @override
  State<_FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<_FriendsView> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!isPlausibleFriendCode(_code.text)) {
      _snack(context, 'Un code ami fait 8 caractères (lettres et chiffres).', error: true);
      return;
    }
    setState(() => _busy = true);
    final (now, err) = await Online.addFriend(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _snack(context, err, error: true);
      return;
    }
    _code.clear();
    _snack(context, now ? 'Vous êtes maintenant amis !' : 'Demande envoyée : elle apparaîtra chez ton ami.');
    await widget.model.refresh();
  }

  Future<void> _act(Future<String?> action, String done) async {
    final err = await action;
    if (!mounted) return;
    _snack(context, err ?? done, error: err != null);
    await widget.model.refresh();
  }

  Future<void> _confirmRemove(Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.night,
        title: Text('Retirer ${f.name} ?', style: const TextStyle(color: Colors.white)),
        content: const Text('Les échanges en attente avec cet ami seront annulés.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok == true) await _act(Online.removeFriend(f.userId), '${f.name} ne fait plus partie de tes amis.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final m = widget.model;
        final incoming = m.friends.where((f) => f.status == FriendStatus.incoming).toList();
        final outgoing = m.friends.where((f) => f.status == FriendStatus.outgoing).toList();
        final friends = m.accepted;
        final code = Online.friendCode;
        return RefreshIndicator(
          onRefresh: m.refresh,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mon code ami', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(code == null ? '…' : formatFriendCode(code),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Copier',
                      onPressed: code == null
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: code));
                              _snack(context, 'Code ami copié : envoie-le à tes amis !');
                            },
                      icon: const Icon(Icons.copy, color: Colors.white),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        style: const TextStyle(color: Colors.white, letterSpacing: 2),
                        decoration: const InputDecoration(
                          hintText: 'Code ami à ajouter',
                          hintStyle: TextStyle(color: Colors.white38, letterSpacing: 0),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChunkyButton(label: 'Ajouter', fontSize: 14, onPressed: _busy ? null : _add),
                  ]),
                ]),
              ),
              if (m.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(m.error!, style: const TextStyle(color: AppColors.coral)),
                ),
              if (incoming.isNotEmpty) ...[
                const SectionTitle('Demandes reçues'),
                for (final f in incoming)
                  _row(
                    f,
                    subtitle: 'Veut devenir ton ami',
                    actions: [
                      IconButton.filled(
                        tooltip: 'Accepter',
                        style: IconButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _act(Online.respondFriend(f.userId, true), 'Vous êtes maintenant amis !'),
                        icon: const Icon(Icons.check),
                      ),
                      IconButton(
                        tooltip: 'Refuser',
                        onPressed: () => _act(Online.respondFriend(f.userId, false), 'Demande refusée.'),
                        icon: const Icon(Icons.close, color: Colors.white60),
                      ),
                    ],
                  ),
              ],
              SectionTitle('Mes amis (${friends.length})',
                  trailing: m.loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : null),
              if (friends.isEmpty)
                const Text('Pas encore d\'amis : partage ton code ami ou ajoute le leur.',
                    style: TextStyle(color: Colors.white60)),
              for (final f in friends)
                _row(
                  f,
                  subtitle: '${f.species} / ${widget.data.pool.cards.length} cartes',
                  actions: [
                    IconButton(
                      tooltip: 'Échanger',
                      onPressed: () => openTradeComposer(context, widget.data, f, widget.model.refresh),
                      icon: const Icon(Icons.swap_horiz, color: AppColors.teal),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white60),
                      onSelected: (_) => _confirmRemove(f),
                      itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Retirer cet ami'))],
                    ),
                  ],
                ),
              if (outgoing.isNotEmpty) ...[
                const SectionTitle('Demandes envoyées'),
                for (final f in outgoing)
                  _row(
                    f,
                    subtitle: 'En attente de réponse',
                    actions: [
                      TextButton(
                        onPressed: () => _act(Online.removeFriend(f.userId), 'Demande annulée.'),
                        child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(Friend f, {required String subtitle, required List<Widget> actions}) => Card(
        color: _panel,
        child: ListTile(
          leading: _avatar(f.name),
          title: Text(f.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
        ),
      );
}

// ------------------------------------------------------------- Échanges

class _TradesView extends StatelessWidget {
  const _TradesView({required this.data, required this.model});
  final AppData data;
  final _SocialModel model;

  Future<void> _new(BuildContext context) async {
    final friends = model.accepted;
    if (friends.isEmpty) {
      _snack(context, 'Ajoute d\'abord un ami (onglet Amis).');
      return;
    }
    final f = friends.length == 1
        ? friends.first
        : await showModalBottomSheet<Friend>(
            context: context,
            backgroundColor: AppColors.night,
            builder: (ctx) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Échanger avec…',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                for (final f in friends)
                  ListTile(
                    leading: _avatar(f.name),
                    title: Text(f.name, style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(ctx, f),
                  ),
              ]),
            ),
          );
    if (f != null && context.mounted) await openTradeComposer(context, data, f, model.refresh);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final incoming = model.trades.where((t) => t.incoming && t.isPending).toList();
        final outgoing = model.trades.where((t) => !t.incoming && t.isPending).toList();
        final history = model.trades.where((t) => !t.isPending).toList();
        return RefreshIndicator(
          onRefresh: model.refresh,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ChunkyButton(
                label: 'Proposer un échange',
                icon: Icons.swap_horiz,
                fontSize: 16,
                color: AppColors.teal,
                onPressed: () => _new(context),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Une carte contre une carte, entre amis, sans restriction de rareté.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              if (model.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(model.error!, style: const TextStyle(color: AppColors.coral)),
                ),
              SectionTitle('Propositions reçues (${incoming.length})'),
              if (incoming.isEmpty) const Text('Aucune pour l\'instant.', style: TextStyle(color: Colors.white60)),
              for (final t in incoming) _TradeTile(data: data, trade: t, model: model),
              if (outgoing.isNotEmpty) ...[
                SectionTitle('Mes propositions (${outgoing.length})'),
                for (final t in outgoing) _TradeTile(data: data, trade: t, model: model),
              ],
              if (history.isNotEmpty) ...[
                const SectionTitle('Historique (30 jours)'),
                for (final t in history) _TradeTile(data: data, trade: t, model: model),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Un échange : la carte que je donne → celle que je reçois, et les boutons selon le cas.
class _TradeTile extends StatefulWidget {
  const _TradeTile({required this.data, required this.trade, required this.model});
  final AppData data;
  final Trade trade;
  final _SocialModel model;

  @override
  State<_TradeTile> createState() => _TradeTileState();
}

class _TradeTileState extends State<_TradeTile> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    final (ok, err) = await Online.acceptTrade(widget.trade.id);
    if (!mounted) return;
    _snack(
      context,
      err ?? (ok ? 'Échange réussi ! La carte a rejoint ta collection.' : 'Trop tard : une des cartes n\'est plus disponible.'),
      error: err != null || !ok,
    );
    setState(() => _busy = false);
    await widget.model.refresh();
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    final err = await Online.closeTrade(widget.trade.id);
    if (!mounted) return;
    _snack(context, err ?? (widget.trade.incoming ? 'Échange refusé.' : 'Proposition annulée.'), error: err != null);
    setState(() => _busy = false);
    await widget.model.refresh();
  }

  Widget _card((int, int) item) {
    final card = widget.data.pool.byId(item.$1);
    if (card == null) return const SizedBox(width: 76);
    return SizedBox(
      width: 76,
      child: CardView(
        card: card,
        instance: CardInstance(card, item.$2),
        isNew: !widget.data.collection.owned.containsKey(card.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final give = widget.data.pool.byId(t.iGive.$1);
    final get = widget.data.pool.byId(t.iGet.$1);
    final title = t.incoming ? '${t.otherName} te propose :' : 'Proposé à ${t.otherName}';
    final statusColor = switch (t.status) {
      TradeStatus.accepted => Colors.greenAccent,
      TradeStatus.pending => AppColors.gold,
      _ => Colors.white38,
    };
    return Card(
      color: _panel,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Text(t.status.label, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Column(children: [const Text('Tu donnes', style: TextStyle(color: Colors.white60, fontSize: 11)), _card(t.iGive)]),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.swap_horiz, color: AppColors.gold, size: 30),
            ),
            Column(children: [const Text('Tu reçois', style: TextStyle(color: Colors.white60, fontSize: 11)), _card(t.iGet)]),
            const Spacer(),
            if (t.isPending && _busy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else if (t.isPending && t.incoming)
              Column(children: [
                IconButton.filled(
                  tooltip: 'Accepter',
                  onPressed: _accept,
                  icon: const Icon(Icons.check),
                  style: IconButton.styleFrom(backgroundColor: Colors.green),
                ),
                IconButton.filled(
                  tooltip: 'Refuser',
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(backgroundColor: AppColors.coral),
                ),
              ])
            else if (t.isPending)
              TextButton(onPressed: _close, child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
          ]),
          if (give != null && get != null) ...[
            const SizedBox(height: 6),
            Text('Tu donnes ${give.name} (${give.rarity.label}), tu reçois ${get.name} (${get.rarity.label}).',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}

/// Ouvre l'écran de composition d'un échange avec [friend].
Future<void> openTradeComposer(BuildContext context, AppData data, Friend friend, Future<void> Function() onSent) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _TradeComposer(data: data, friend: friend, onSent: onSent),
    ));

class _TradeComposer extends StatefulWidget {
  const _TradeComposer({required this.data, required this.friend, required this.onSent});
  final AppData data;
  final Friend friend;
  final Future<void> Function() onSent;

  @override
  State<_TradeComposer> createState() => _TradeComposerState();
}

class _TradeComposerState extends State<_TradeComposer> {
  List<ServerCard>? _mine;
  List<ServerCard>? _theirs;
  String? _error;
  ServerCard? _give;
  ServerCard? _get;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Mes cartes en ligne : la synchro d'abord, pour pouvoir offrir aussi les cartes de l'appareil.
    await Online.sync();
    final (mine, e1) = await Online.cardsOf(null);
    final (theirs, e2) = await Online.cardsOf(widget.friend.userId);
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _theirs = theirs;
      _error = e1 ?? e2;
    });
  }

  /// Trie de la plus rare à la plus commune, puis par nom.
  List<ServerCard> _sorted(List<ServerCard> cards) {
    final pool = widget.data.pool;
    final list = cards.where((c) => pool.byId(c.cardId) != null).toList();
    list.sort((a, b) {
      final ca = pool.byId(a.cardId)!, cb = pool.byId(b.cardId)!;
      final r = cb.rarity.index.compareTo(ca.rarity.index);
      return r != 0 ? r : ca.name.compareTo(cb.name);
    });
    return list;
  }

  Future<ServerCard?> _pick(List<ServerCard> cards, String title, {required bool markNew}) {
    final pool = widget.data.pool;
    final owned = widget.data.collection.owned;
    final sorted = _sorted(cards);
    return showModalBottomSheet<ServerCard>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            if (markNew)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('« Nouveau » = carte que tu n\'as pas encore.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            Expanded(
              child: sorted.isEmpty
                  ? const Center(child: Text('Aucune carte.', style: TextStyle(color: Colors.white60)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 120,
                        childAspectRatio: 0.72,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (_, i) {
                        final sc = sorted[i];
                        final card = pool.byId(sc.cardId)!;
                        return CardView(
                          card: card,
                          instance: CardInstance(card, sc.seed),
                          quantity: markNew ? null : owned[card.id],
                          isNew: markNew && !owned.containsKey(card.id),
                          onTap: () => Navigator.pop(ctx, sc),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final give = _give, get = _get;
    if (give == null || get == null) return;
    setState(() => _sending = true);
    final err = await Online.proposeTrade(widget.friend.userId, give.rowId, get.rowId);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      _snack(context, err, error: true);
      return;
    }
    await widget.onSent();
    if (!mounted) return;
    _snack(context, 'Proposition envoyée à ${widget.friend.name} !');
    Navigator.of(context).pop();
  }

  Widget _slot(String label, ServerCard? sc, VoidCallback? onTap) {
    final card = sc == null ? null : widget.data.pool.byId(sc.cardId);
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      SizedBox(
        width: 130,
        child: card != null
            ? CardView(card: card, instance: CardInstance(card, sc!.seed), onTap: onTap)
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

  @override
  Widget build(BuildContext context) {
    final loading = _mine == null && _error == null;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: Text('Échange avec ${widget.friend.name}'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.coral)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _slot('Je donne', _give, _mine == null
                    ? null
                    : () async {
                        final c = await _pick(_mine!, 'Carte à donner', markNew: false);
                        if (c != null) setState(() => _give = c);
                      }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.swap_horiz, color: AppColors.gold, size: 36),
                ),
                _slot('Je reçois', _get, _theirs == null
                    ? null
                    : () async {
                        final c = await _pick(_theirs!, 'Cartes de ${widget.friend.name}', markNew: true);
                        if (c != null) setState(() => _get = c);
                      }),
              ]),
              const SizedBox(height: 12),
              Text(
                'Touche une case pour choisir. ${widget.friend.name} devra accepter : les cartes ne changent '
                'de main qu\'à ce moment-là. Le chiffre sur tes cartes = combien d\'exemplaires tu en as '
                '(les doublons sont parfaits pour échanger).',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ChunkyButton(
                label: _sending ? 'Envoi…' : 'Envoyer la proposition',
                fontSize: 16,
                color: AppColors.teal,
                onPressed: _give != null && _get != null && !_sending ? _send : null,
              ),
            ]),
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
          child: Text('Aperçu : le format des combats reste à définir (idées de Clem à venir).',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ]),
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
