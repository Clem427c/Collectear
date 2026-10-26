import 'package:flutter/services.dart';

import 'core/cards.dart';
import 'core/collection.dart';

/// Données chargées au démarrage : les 300 cartes et la collection du joueur.
class AppData {
  const AppData(this.pool, this.collection);
  final CardPool pool;
  final Collection collection;

  static Future<AppData> load() async {
    final json = await rootBundle.loadString('assets/data/cards.json');
    final pool = CardPool.fromJsonString(json);
    final collection = await Collection.load();
    return AppData(pool, collection);
  }

  /// Cartes possédées, triées de la plus rare à la plus commune.
  List<GameCard> get ownedCards {
    final list = collection.owned.keys.map(pool.byId).whereType<GameCard>().toList();
    list.sort((a, b) {
      final r = b.rarity.index.compareTo(a.rarity.index);
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return list;
  }

  GameCard? get companion {
    final id = collection.companionId;
    if (id == null || !collection.owned.containsKey(id)) return null;
    return pool.byId(id);
  }
}
