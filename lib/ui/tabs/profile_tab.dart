import 'package:flutter/material.dart';

import '../../app_data.dart';
import '../../core/cards.dart';
import '../../core/cloud_sync.dart';
import '../../online.dart';
import '../theme.dart';
import '../widgets.dart';

/// Onglet Profil d'explorateur : statistiques et progression par rareté.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Online.revision,
        builder: (context, _, __) => _build(context),
      );

  Widget _build(BuildContext context) {
    final col = data.collection;
    final cards = data.pool.cards;
    final stats = ProfileStats(
      runs: col.totalRuns,
      kills: col.totalKills,
      cards: col.totalCards,
      bestKills: col.bestKills,
    ).merge(Online.user == null ? null : Online.stats);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.violet,
            child: Icon(Icons.explore, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: () => _editPseudo(context, col.pseudo),
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  Flexible(
                    child: Text(col.pseudo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, color: Colors.white54, size: 18),
                ]),
              ),
              Text('Code ami : ${Online.friendCode ?? col.friendCode}', style: const TextStyle(color: Colors.white60)),
              if (Online.user?.email != null)
                Text(Online.user!.email!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
        ]),
        const SectionTitle('Statistiques'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _StatBox(icon: Icons.explore, label: 'Runs jouées', value: '${stats.runs}'),
            _StatBox(icon: Icons.sports_martial_arts, label: 'Ennemis vaincus', value: '${stats.kills}'),
            _StatBox(icon: Icons.style, label: 'Cartes gagnées', value: '${stats.cards}'),
            _StatBox(icon: Icons.emoji_events, label: 'Record de kills', value: '${stats.bestKills}'),
          ],
        ),
        const SectionTitle('Bestiaire par rareté'),
        for (final r in Rarity.values.reversed)
          _RarityBar(
            rarity: r,
            owned: cards.where((c) => c.rarity == r && col.owned.containsKey(c.id)).length,
            total: cards.where((c) => c.rarity == r).length,
          ),
      ],
    );
  }
}

/// Fenêtre de changement de pseudo (enregistré sur l'appareil, et en ligne si connecté).
Future<void> _editPseudo(BuildContext context, String current) async {
  await showDialog<void>(context: context, builder: (_) => _PseudoDialog(current: current));
}

class _PseudoDialog extends StatefulWidget {
  const _PseudoDialog({required this.current});
  final String current;

  @override
  State<_PseudoDialog> createState() => _PseudoDialogState();
}

class _PseudoDialogState extends State<_PseudoDialog> {
  late final _ctrl = TextEditingController(text: widget.current == defaultPseudo ? '' : widget.current);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final err = await Online.setPseudo(_ctrl.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A1F66),
      title: const Text('Ton pseudo', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: maxPseudoLength,
        enabled: !_busy,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: defaultPseudo,
          hintStyle: const TextStyle(color: Colors.white38),
          errorText: _error,
          counterStyle: const TextStyle(color: Colors.white38),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: _busy ? null : _save,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF3A2D86), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: AppColors.gold, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _RarityBar extends StatelessWidget {
  const _RarityBar({required this.rarity, required this.owned, required this.total});
  final Rarity rarity;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(rarity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(rarity.label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$owned / $total', style: const TextStyle(color: Colors.white)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : owned / total,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

