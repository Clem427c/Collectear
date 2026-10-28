import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync.dart' show defaultPseudo, normalizePseudo;
import 'config.dart';
import 'economy.dart';

/// Collection du joueur et compteur de runs du jour, stockés en local.
/// (La sauvegarde en ligne via Supabase viendra à l'étape « En ligne ».)
class Collection {
  Collection._(this._prefs);

  static const _kOwned = 'owned_cards'; // "id:quantité"
  static const _kCompanion = 'companion_id';
  static const _kRunsDay = 'runs_day';
  static const _kRunsCount = 'runs_count';
  static const _kTotalRuns = 'stat_runs';
  static const _kTotalKills = 'stat_kills';
  static const _kTotalCards = 'stat_cards';
  static const _kBestKills = 'stat_best_kills';
  static const _kFriendCode = 'friend_code';
  static const _kPseudo = 'pseudo';
  static const _kCoins = 'coins';
  static const _kEnergyDay = 'energy_day';
  static const _kEnergyBought = 'energy_bought';

  static const _kVariants = 'owned_variants'; // "id:seed1,seed2,…"

  final SharedPreferences _prefs;

  /// Exemplaires possédés : id de carte → seeds des variantes obtenues.
  final Map<int, List<int>> variants = {};

  /// Nombre d'exemplaires par carte (compatibilité avec les écrans existants).
  Map<int, int> get owned => {for (final e in variants.entries) e.key: e.value.length};

  static Future<Collection> load() async {
    final prefs = await SharedPreferences.getInstance();
    final c = Collection._(prefs);
    final stored = prefs.getStringList(_kVariants);
    if (stored != null) {
      for (final entry in stored) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final id = int.tryParse(parts[0]);
        if (id == null) continue;
        final seeds = parts[1].split(',').map(int.tryParse).whereType<int>().toList();
        if (seeds.isNotEmpty) c.variants[id] = seeds;
      }
    } else {
      // Migration de l'ancien format "id:quantité" : variantes déterministes.
      for (final entry in prefs.getStringList(_kOwned) ?? const <String>[]) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final id = int.tryParse(parts[0]);
        final qty = int.tryParse(parts[1]);
        if (id != null && qty != null && qty > 0) {
          c.variants[id] = [for (var i = 0; i < qty; i++) id * 7919 + i];
        }
      }
      await c._save();
    }
    return c;
  }

  Future<void> _save() => _prefs.setStringList(
      _kVariants, variants.entries.map((e) => '${e.key}:${e.value.join(',')}').toList());

  int get distinctCount => variants.length;

  int? get companionId => _prefs.getInt(_kCompanion);

  Future<void> setCompanion(int? id) async {
    if (id == null) {
      await _prefs.remove(_kCompanion);
    } else {
      await _prefs.setInt(_kCompanion, id);
    }
  }

  /// Ajoute des exemplaires (id, seed de variante) ; renvoie les ids nouvellement découverts.
  Future<Set<int>> addAll(Iterable<(int, int)> items) async {
    final fresh = <int>{};
    for (final (id, seed) in items) {
      if (!variants.containsKey(id)) fresh.add(id);
      (variants[id] ??= []).add(seed);
    }
    await _save();
    return fresh;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  int get runsToday => _prefs.getString(_kRunsDay) == _today() ? (_prefs.getInt(_kRunsCount) ?? 0) : 0;

  /// Runs disponibles aujourd'hui : les gratuites + les énergies achetées avec des pièces.
  int get runsLeftToday => math.max(0, GameConfig.runsPerDay + energyBoughtToday - runsToday);

  // --- Pièces et énergies ---
  int get coins => _prefs.getInt(_kCoins) ?? 0;

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    await _prefs.setInt(_kCoins, coins + amount);
  }

  /// Énergies achetées aujourd'hui avec des pièces (au plus Economy.maxEnergyPurchasesPerDay).
  int get energyBoughtToday => _prefs.getString(_kEnergyDay) == _today() ? (_prefs.getInt(_kEnergyBought) ?? 0) : 0;

  /// Prix de la prochaine énergie (null : limite du jour atteinte).
  int? get nextEnergyPrice => Economy.energyPrice(energyBoughtToday);

  /// On n'achète une énergie que si toutes les runs du jour sont épuisées (elle ne se garde pas).
  bool get canBuyEnergy {
    final price = nextEnergyPrice;
    return price != null && coins >= price && runsLeftToday == 0;
  }

  /// Achète une énergie : +1 run aujourd'hui. Renvoie false si ce n'est pas possible.
  Future<bool> buyEnergy() async {
    final price = nextEnergyPrice;
    if (!canBuyEnergy || price == null) return false;
    final bought = energyBoughtToday + 1;
    await _prefs.setInt(_kCoins, coins - price);
    await _prefs.setString(_kEnergyDay, _today());
    await _prefs.setInt(_kEnergyBought, bought);
    return true;
  }

  /// Outil de test : remet le compteur du jour à zéro (appui long sur le titre).
  Future<void> resetRunsToday() async => _prefs.remove(_kRunsCount);

  Future<void> registerRun() async {
    final count = runsToday + 1;
    await _prefs.setString(_kRunsDay, _today());
    await _prefs.setInt(_kRunsCount, count);
  }

  // --- Statistiques du profil d'explorateur ---
  int get totalRuns => _prefs.getInt(_kTotalRuns) ?? 0;
  int get totalKills => _prefs.getInt(_kTotalKills) ?? 0;
  int get totalCards => _prefs.getInt(_kTotalCards) ?? 0;
  int get bestKills => _prefs.getInt(_kBestKills) ?? 0;

  Future<void> recordRunResult({required int kills, required int cards}) async {
    await _prefs.setInt(_kTotalRuns, totalRuns + 1);
    await _prefs.setInt(_kTotalKills, totalKills + kills);
    await _prefs.setInt(_kTotalCards, totalCards + cards);
    if (kills > bestKills) await _prefs.setInt(_kBestKills, kills);
  }

  /// Pseudo affiché dans le Profil (et en ligne une fois connecté).
  String get pseudo => _prefs.getString(_kPseudo) ?? defaultPseudo;
  Future<void> setPseudo(String p) => _prefs.setString(_kPseudo, normalizePseudo(p));

  /// Code ami local (prototype ; deviendra l'identifiant du compte en ligne).
  String get friendCode {
    final existing = _prefs.getString(_kFriendCode);
    if (existing != null) return existing;
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = DateTime.now().microsecondsSinceEpoch;
    final code = List.generate(8, (i) => chars[(seed ~/ (i * 7 + 3) + i * 13) % chars.length]).join();
    _prefs.setString(_kFriendCode, code);
    return code;
  }
}
