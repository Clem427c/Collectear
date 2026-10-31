/// Logique pure des amis et des échanges (testée sans réseau).
/// Côté serveur : supabase/schema.sql (friendships, trades, traded_away et leurs fonctions).
library;

import 'cards.dart';
import 'wishlist.dart';

/// Alphabet des codes ami (sans 0/O ni 1/I), comme public.new_friend_code() côté serveur.
const String friendCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int friendCodeLength = 8;

/// Fréquence à laquelle l'onglet Social recharge amis et échanges (en attendant les notifications push).
const Duration socialRefreshInterval = Duration(seconds: 90);

/// Code ami saisi par le joueur : majuscules, sans espaces ni tirets.
String normalizeFriendCode(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Vrai si le code a la bonne forme (8 caractères de l'alphabet).
bool isPlausibleFriendCode(String s) {
  final c = normalizeFriendCode(s);
  return c.length == friendCodeLength && c.split('').every(friendCodeAlphabet.contains);
}

/// Code affiché en deux blocs lisibles : « ABCD EFGH ».
String formatFriendCode(String code) {
  final c = normalizeFriendCode(code);
  return c.length == friendCodeLength ? '${c.substring(0, 4)} ${c.substring(4)}' : c;
}

/// Message en français pour une erreur renvoyée par les fonctions amis / échanges du serveur.
String socialErrorMessage(String message) {
  const known = {
    'code_inconnu': 'Aucun joueur n\'a ce code ami.',
    'code_perso': 'C\'est ton propre code ami !',
    'trop_amis': 'Tu as atteint le nombre maximal d\'amis.',
    'deja_amis': 'Vous êtes déjà amis.',
    'deja_demande': 'Demande déjà envoyée : attends qu\'il l\'accepte.',
    'demande_inconnue': 'Cette demande n\'existe plus.',
    'pas_ami': 'Vous n\'êtes plus amis.',
    'carte_offerte_absente': 'Tu ne possèdes plus cette carte.',
    'carte_demandee_absente': 'Ton ami ne possède plus cette carte.',
    'carte_favorite': 'Une des cartes est en favori : elle doit d\'abord être retirée des favoris.',
    'nombre_cartes': 'Choisis de 1 à $maxTradeSide cartes de chaque côté.',
    'carte_en_double': 'La même carte est choisie deux fois.',
    'trop_propositions': 'Trop de propositions en attente : attends des réponses ou annules-en.',
    'deja_propose': 'Tu as déjà proposé cet échange.',
    'echange_inconnu': 'Cet échange n\'est plus en attente.',
    'trop_souhaits': 'Ta liste de souhaits est pleine ($maxWishes cartes) : retires-en une d\'abord.',
    'carte_inconnue': 'Cette carte n\'existe pas.',
  };
  for (final e in known.entries) {
    if (message.contains(e.key)) return e.value;
  }
  if (message.contains('Could not find the function') || message.contains('PGRST202')) {
    return 'Le serveur n\'est pas encore à jour (Clem doit recoller supabase/schema.sql).';
  }
  return message;
}

/// Un exemplaire vu par le serveur : identifiant de ligne (owned_cards.id), carte et variante.
class ServerCard {
  const ServerCard(this.rowId, this.cardId, this.seed, {this.favorite = false});
  final int rowId;
  final int cardId;
  final int seed;

  /// En favori chez son propriétaire : ne peut être ni offert ni demandé dans un échange.
  final bool favorite;

  static List<ServerCard> fromRows(Iterable<dynamic> rows) => [
        for (final r in rows)
          if (r is Map && _int(r['id']) != null && _int(r['card_id']) != null && _int(r['seed']) != null)
            ServerCard(_int(r['id'])!, _int(r['card_id'])!, _int(r['seed'])!, favorite: r['favorite'] == true),
      ];
}

/// Nombre maximal d'exemplaires de chaque côté d'un échange (comme max_side dans schema.sql).
// PROVISOIRE : 5 de chaque côté (2 contre 1, 3 contre 2… validés par Clem le 28/10, le plafond reste à confirmer).
const int maxTradeSide = 5;

/// Ajoute ou retire [item] de la sélection d'un côté de l'échange. Renvoie la nouvelle sélection,
/// ou null si l'ajout est refusé (côté plein, ou exemplaire en favori).
List<ServerCard>? toggleTradePick(List<ServerCard> picked, ServerCard item) {
  if (picked.any((c) => c.rowId == item.rowId)) return [for (final c in picked) if (c.rowId != item.rowId) c];
  if (item.favorite || picked.length >= maxTradeSide) return null;
  return [...picked, item];
}

int? _int(Object? v) => switch (v) { final int i => i, final num n => n.toInt(), final String s => int.tryParse(s), _ => null };

enum FriendStatus { friend, incoming, outgoing }

/// Un ami, ou une demande en attente (reçue ou envoyée).
class Friend {
  const Friend({required this.userId, required this.name, required this.code, required this.status, this.species = 0});
  final String userId;
  final String name;
  final String code;
  final FriendStatus status;

  /// Nombre de cartes différentes (0 tant que la demande n'est pas acceptée).
  final int species;

  static List<Friend> fromRows(Iterable<dynamic> rows) {
    final out = <Friend>[];
    for (final r in rows) {
      if (r is! Map || r['user_id'] is! String) continue;
      final accepted = r['status'] == 'accepted';
      out.add(Friend(
        userId: r['user_id'] as String,
        name: (r['display_name'] as String?) ?? '?',
        code: (r['friend_code'] as String?) ?? '',
        status: accepted ? FriendStatus.friend : (r['incoming'] == true ? FriendStatus.incoming : FriendStatus.outgoing),
        species: _int(r['species']) ?? 0,
      ));
    }
    return out;
  }
}

enum TradeStatus { pending, accepted, declined, cancelled, expired }

extension TradeStatusInfo on TradeStatus {
  String get label => const ['En attente', 'Accepté', 'Refusé', 'Annulé', 'Expiré'][index];
}

/// Un échange vu par le joueur : « offered » est toujours la carte de l'auteur de la proposition.
class Trade {
  const Trade({
    required this.id,
    required this.incoming,
    required this.otherUser,
    required this.otherName,
    required this.offered,
    required this.requested,
    required this.status,
  });
  final int id;

  /// Vrai si la proposition vient de l'ami (c'est à moi de répondre).
  final bool incoming;
  final String otherUser;
  final String otherName;

  /// Exemplaires (id de carte, seed) de l'auteur de la proposition, et ceux qu'il demande.
  final List<(int, int)> offered;
  final List<(int, int)> requested;
  final TradeStatus status;

  /// Ce que je donne et ce que je reçois si l'échange se fait.
  List<(int, int)> get iGive => incoming ? requested : offered;
  List<(int, int)> get iGet => incoming ? offered : requested;

  bool get isPending => status == TradeStatus.pending;

  static List<(int, int)> _items(Object? v) => [
        if (v is List)
          for (final e in v)
            if (e is Map && _int(e['card_id']) != null && _int(e['seed']) != null) (_int(e['card_id'])!, _int(e['seed'])!),
      ];

  static List<Trade> fromRows(Iterable<dynamic> rows) {
    final out = <Trade>[];
    for (final r in rows) {
      if (r is! Map) continue;
      final id = _int(r['id']);
      final status = TradeStatus.values.where((s) => s.name == r['status']).firstOrNull;
      final offered = _items(r['offered']), requested = _items(r['requested']);
      if (id == null || status == null || offered.isEmpty || requested.isEmpty) continue;
      out.add(Trade(
        id: id,
        incoming: r['incoming'] == true,
        otherUser: (r['other_user'] as String?) ?? '',
        otherName: (r['other_name'] as String?) ?? '?',
        offered: offered,
        requested: requested,
        status: status,
      ));
    }
    return out;
  }
}

/// Exemplaires de la collection locale qui ont été donnés lors d'un échange (liste traded_away du
/// serveur) et doivent donc en être retirés. Un exemplaire est (id de carte, seed).
List<(int, int)> givenAwayStillLocal(Map<int, List<int>> local, Iterable<(int, int)> tradedAway) => [
      for (final (id, seed) in tradedAway.toSet())
        if (local[id]?.contains(seed) ?? false) (id, seed),
    ];

/// Nombre d'actions qui attendent le joueur (demandes d'ami et échanges reçus) : pastille de l'onglet.
int pendingActions(List<Friend> friends, List<Trade> trades) =>
    friends.where((f) => f.status == FriendStatus.incoming).length +
    trades.where((t) => t.incoming && t.isPending).length;

/// Une ligne du classement entre amis (fonction serveur friends_leaderboard).
class LeaderboardEntry {
  const LeaderboardEntry({
    this.userId = '',
    required this.name,
    required this.isMe,
    required this.species,
    required this.copies,
    required this.bestKills,
  });
  final String userId;
  final String name;
  final bool isMe;

  /// Cartes différentes, exemplaires au total, record d'ennemis vaincus en une run.
  final int species;
  final int copies;
  final int bestKills;

  /// Lit les lignes du serveur et les range : cartes différentes, puis exemplaires, puis pseudo.
  static List<LeaderboardEntry> fromRows(Iterable<dynamic> rows) {
    final out = [
      for (final r in rows)
        if (r is Map && r['display_name'] is String)
          LeaderboardEntry(
            userId: (r['user_id'] as String?) ?? '',
            name: r['display_name'] as String,
            isMe: r['is_me'] == true,
            species: _int(r['species']) ?? 0,
            copies: _int(r['copies']) ?? 0,
            bestKills: _int(r['best_kills']) ?? 0,
          ),
    ];
    out.sort((a, b) {
      final s = b.species.compareTo(a.species);
      if (s != 0) return s;
      final c = b.copies.compareTo(a.copies);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }
}

/// Rang affiché de chaque ligne (déjà triée) : les ex æquo (mêmes cartes et exemplaires) partagent le rang.
List<int> leaderboardRanks(List<LeaderboardEntry> entries) {
  final ranks = <int>[];
  for (var i = 0; i < entries.length; i++) {
    final same = i > 0 && entries[i].species == entries[i - 1].species && entries[i].copies == entries[i - 1].copies;
    ranks.add(same ? ranks[i - 1] : i + 1);
  }
  return ranks;
}

/// Filtres de la collection d'un ami.
enum FriendCardFilter { all, iLack, duplicates, myWishes }

extension FriendCardFilterInfo on FriendCardFilter {
  String get label => const ['Toutes', 'Il a, pas toi', 'Ses doublons', 'Mes souhaits'][index];
}

/// Collection d'un ami vue depuis son profil : regroupée par espèce, comparée à la mienne.
class FriendCollection {
  /// [cards] : exemplaires de l'ami (fonction serveur friend_cards) ; [mine] : mes quantités par carte.
  /// Les cartes inconnues du jeu (id hors du classeur) sont ignorées.
  /// [myWishes] : ma liste de souhaits (filtre « Mes souhaits » : ce qu'il a parmi ce que je cherche).
  FriendCollection(Iterable<ServerCard> cards, this.pool, Map<int, int> mine, {Iterable<int> myWishes = const []})
      : _mine = Map.unmodifiable(mine),
        _wishes = Set.unmodifiable(myWishes) {
    for (final c in cards) {
      if (pool.byId(c.cardId) == null) continue;
      bySpecies.putIfAbsent(c.cardId, () => []).add(c);
    }
  }

  final CardPool pool;
  final Map<int, int> _mine;
  final Set<int> _wishes;

  /// Exemplaires de l'ami par espèce (id de carte).
  final Map<int, List<ServerCard>> bySpecies = {};

  int get species => bySpecies.length;
  int get copies => bySpecies.values.fold(0, (n, l) => n + l.length);

  /// Espèces de l'ami que je n'ai pas encore (cartes à lui demander).
  int get iLackCount => bySpecies.keys.where((id) => (_mine[id] ?? 0) == 0).length;

  /// Mes espèces qu'il n'a pas (cartes que je peux lui proposer).
  int get heLacksCount => _mine.entries.where((e) => e.value > 0 && !bySpecies.containsKey(e.key) && pool.byId(e.key) != null).length;

  /// Par rareté : (espèces possédées par l'ami, espèces existantes).
  Map<Rarity, (int, int)> get byRarity => {
        for (final r in Rarity.values)
          r: (
            bySpecies.keys.where((id) => pool.byId(id)!.rarity == r).length,
            pool.cards.where((c) => c.rarity == r).length,
          ),
      };

  bool _keep(int id, FriendCardFilter f) => switch (f) {
        FriendCardFilter.all => true,
        FriendCardFilter.iLack => (_mine[id] ?? 0) == 0,
        FriendCardFilter.duplicates => bySpecies[id]!.length > 1,
        FriendCardFilter.myWishes => _wishes.contains(id),
      };

  /// Espèces à afficher pour un filtre : de la plus rare à la plus commune, puis par nom.
  List<GameCard> cards(FriendCardFilter filter) {
    final list = [for (final id in bySpecies.keys) if (_keep(id, filter)) pool.byId(id)!];
    list.sort((a, b) {
      final r = b.rarity.index.compareTo(a.rarity.index);
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return list;
  }
}
