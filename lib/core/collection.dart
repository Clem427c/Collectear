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
}
