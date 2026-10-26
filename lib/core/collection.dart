import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

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

  final SharedPreferences _prefs;
  final Map<int, int> owned = {};

  static Future<Collection> load() async {
    final prefs = await SharedPreferences.getInstance();
    final c = Collection._(prefs);
    for (final entry in prefs.getStringList(_kOwned) ?? const <String>[]) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      final id = int.tryParse(parts[0]);
      final qty = int.tryParse(parts[1]);
      if (id != null && qty != null && qty > 0) c.owned[id] = qty;
    }
    return c;
  }

  int get distinctCount => owned.length;

  int? get companionId => _prefs.getInt(_kCompanion);

  Future<void> setCompanion(int? id) async {
    if (id == null) {
      await _prefs.remove(_kCompanion);
    } else {
      await _prefs.setInt(_kCompanion, id);
    }
  }

  /// Ajoute des cartes ; renvoie les ids nouvellement découverts.
  Future<Set<int>> addAll(Iterable<int> ids) async {
    final fresh = <int>{};
    for (final id in ids) {
      if (!owned.containsKey(id)) fresh.add(id);
      owned[id] = (owned[id] ?? 0) + 1;
    }
    await _prefs.setStringList(_kOwned, owned.entries.map((e) => '${e.key}:${e.value}').toList());
    return fresh;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  int get runsToday => _prefs.getString(_kRunsDay) == _today() ? (_prefs.getInt(_kRunsCount) ?? 0) : 0;

  int get runsLeftToday => (GameConfig.runsPerDay - runsToday).clamp(0, GameConfig.runsPerDay);

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
