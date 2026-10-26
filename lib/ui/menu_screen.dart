import 'package:flutter/material.dart';

import '../core/cards.dart';
import '../core/config.dart';
import '../main.dart';
import 'bestiary_screen.dart';
import 'run_screen.dart';
import 'theme.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.data});
  final AppData data;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  AppData get data => widget.data;

  List<GameCard> get _owned {
    final list = data.collection.owned.keys.map(data.pool.byId).whereType<GameCard>().toList();
    list.sort((a, b) {
      final r = b.rarity.index.compareTo(a.rarity.index);
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return list;
  }

  GameCard? get _companion {
    final id = data.collection.companionId;
    if (id == null || !data.collection.owned.containsKey(id)) return null;
    return data.pool.byId(id);
  }

  Future<void> _startRun() async {
    final col = data.collection;
    if (col.runsLeftToday <= 0) return;
    await col.registerRun();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RunScreen(data: data, companion: _companion),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _pickCompanion() async {
    final owned = _owned;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Choisis ton compagnon de run', style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Aucun compagnon'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            for (final c in owned)
              ListTile(
                leading: CircleAvatar(backgroundColor: rarityColor(c.rarity), radius: 8),
                title: Text(c.name),
                subtitle: Text('${c.rarity.label} · Boost ${c.boost.label} : ${c.boost.description}'),
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await data.collection.setCompanion(picked == -1 ? null : picked);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final col = data.collection;
    final companion = _companion;
    final runsLeft = col.runsLeftToday;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onLongPress: () async {
                    await col.resetRunsToday();
                    if (mounted) setState(() {});
                  },
                  child: const Text('Collectear',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const Text('Explore. Débloque. Collectionne.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold, fontSize: 16)),
                const SizedBox(height: 32),
                _StatRow(label: 'Bestiaire', value: '${col.distinctCount} / ${data.pool.cards.length}'),
                _StatRow(label: 'Runs restantes aujourd\'hui', value: '$runsLeft / ${GameConfig.runsPerDay}'),
                const SizedBox(height: 16),
                Card(
                  color: AppColors.night,
                  child: ListTile(
                    leading: Icon(Icons.pets, color: companion != null ? rarityColor(companion.rarity) : Colors.white54),
                    title: Text(companion?.name ?? 'Aucun compagnon'),
                    subtitle: Text(companion != null
                        ? 'Boost ${companion.boost.label} : ${companion.boost.description}'
                        : col.distinctCount == 0
                            ? 'Gagne des cartes pour choisir un compagnon'
                            : 'Touche pour choisir un compagnon'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: col.distinctCount == 0 ? null : _pickCompanion,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: runsLeft > 0 ? _startRun : null,
                  child: Text(runsLeft > 0 ? 'Lancer une run (2 min)' : 'Plus de run aujourd\'hui',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => BestiaryScreen(data: data),
                  )),
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Bestiaire')),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Contrôles clavier : ZQSD / WASD / flèches · Espace = saut · J = attaque · K = esquive',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text('Prototype v0.1', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
