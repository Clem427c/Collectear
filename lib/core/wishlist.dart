/// Liste de souhaits partagée (GDD, diapo « Compte, amis, échanges ») : les cartes que je cherche,
/// visibles par mes amis pour qu'ils sachent quoi me proposer. Logique pure, testée sans réseau.
/// Côté serveur : table public.wishlist et fonctions set_wish / my_wishlist / friend_wishlist.
library;

import 'cards.dart';

/// Nombre maximal de cartes dans sa liste de souhaits (comme max_wishes dans schema.sql).
// PROVISOIRE : 30 cartes ; assez pour viser une rareté entière sans transformer la liste en bestiaire.
const int maxWishes = 30;

/// Lit les lignes du serveur ([{card_id: 12}, …]) : identifiants valides, sans doublon, dans l'ordre reçu.
List<int> wishesFromRows(Iterable<dynamic> rows) {
  final out = <int>[];
  for (final r in rows) {
    final v = r is Map ? r['card_id'] : null;
    final id = switch (v) { final int i => i, final num n => n.toInt(), final String s => int.tryParse(s), _ => null };
    if (id != null && id > 0 && !out.contains(id)) out.add(id);
  }
  return out;
}

/// Ajoute ou retire [cardId] de la liste. Renvoie la nouvelle liste, ou null si elle est pleine.
List<int>? toggleWish(List<int> wishes, int cardId) {
  if (wishes.contains(cardId)) return [for (final id in wishes) if (id != cardId) id];
  if (wishes.length >= maxWishes) return null;
  return [...wishes, cardId];
}

/// Un souhait d'un ami vu de mon côté : la carte, et combien d'exemplaires j'en ai à lui proposer
/// (mes exemplaires hors favoris, qui ne peuvent pas être échangés).
class WishMatch {
  const WishMatch(this.card, this.giveable, this.owned);
  final GameCard card;

  /// Exemplaires que je pourrais lui donner (possédés, hors favoris).
  final int giveable;

  /// Exemplaires que je possède (favoris compris).
  final int owned;

  bool get canGive => giveable > 0;
}

/// Souhaits d'un ami comparés à ma collection : d'abord ceux que je peux lui donner, puis
/// de la plus rare à la plus commune, puis par nom. Les cartes inconnues du jeu sont ignorées.
/// [mine] : mes quantités par carte ; [myFavorites] : mes exemplaires en favori par carte.
List<WishMatch> matchWishes(Iterable<int> theirWishes, CardPool pool, Map<int, int> mine,
    {Map<int, int> myFavorites = const {}}) {
  final out = <WishMatch>[];
  for (final id in theirWishes.toSet()) {
    final card = pool.byId(id);
    if (card == null) continue;
    final owned = mine[id] ?? 0;
    final giveable = (owned - (myFavorites[id] ?? 0)).clamp(0, owned);
    out.add(WishMatch(card, giveable, owned));
  }
  out.sort((a, b) {
    if (a.canGive != b.canGive) return a.canGive ? -1 : 1;
    final r = b.card.rarity.index.compareTo(a.card.rarity.index);
    return r != 0 ? r : a.card.name.compareTo(b.card.name);
  });
  return out;
}

/// Mes souhaits dans l'ordre d'affichage : de la plus rare à la plus commune, puis par nom.
List<GameCard> sortedWishes(Iterable<int> wishes, CardPool pool) {
  final list = [for (final id in wishes.toSet()) if (pool.byId(id) != null) pool.byId(id)!];
  list.sort((a, b) {
    final r = b.rarity.index.compareTo(a.rarity.index);
    return r != 0 ? r : a.name.compareTo(b.name);
  });
  return list;
}
