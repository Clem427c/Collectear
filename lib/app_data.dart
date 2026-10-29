import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'ads/ads.dart';
import 'core/cards.dart';
import 'core/collection.dart';
import 'core/settings.dart';
import 'game/sfx.dart';
import 'online.dart';

/// Données chargées au démarrage : les 300 cartes et la collection du joueur.
class AppData {
  const AppData(this.pool, this.collection, this.settings);
  final CardPool pool;
  final Collection collection;
  final Settings settings;

  static Future<AppData> load() async {
    final json = await rootBundle.loadString('assets/data/cards.json');
    final pool = CardPool.fromJsonString(json);
    final collection = await Collection.load();
    final settings = await Settings.load();
    Sfx.volumeLevel = settings.volume;
    Sfx.hapticsEnabled = settings.haptics;
    await Illustrations.load();
    await Online.init();
    Online.attach(collection);
    // Vidéos récompensées : initialisées en arrière-plan (ne retarde pas le démarrage).
    unawaited(Ads.init());
    return AppData(pool, collection, settings);
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

/// Numéros des cartes qui ont une illustration (assets/cards/NNN.png, générés en CI
/// à partir de art/raw/ par tool/process_art.py).
class Illustrations {
  Illustrations._();
  static Set<int> available = {};

  static Future<void> load() async {
    try {
      final json = await rootBundle.loadString('assets/cards/manifest.json');
      available = (jsonDecode(json) as List).cast<int>().toSet();
    } catch (_) {
      available = {};
    }
  }

  static String path(int id) => 'assets/cards/${id.toString().padLeft(3, '0')}.png';
}
