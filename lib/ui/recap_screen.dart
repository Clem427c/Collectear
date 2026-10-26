import 'package:flutter/material.dart';

import '../core/cards.dart';
import '../core/run_state.dart';
import 'card_tile.dart';
import 'theme.dart';

class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key, required this.run, required this.freshIds, this.companion});
  final RunState run;
  final Set<int> freshIds;
  final GameCard? companion;

  @override
  Widget build(BuildContext context) {
    final reason = run.endReason ?? RunEndReason.quit;
    final success = reason == RunEndReason.cardsCollected;
    final secs = run.elapsed.round();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(success ? Icons.emoji_events : Icons.flag, size: 56, color: success ? AppColors.gold : Colors.white70),
                const SizedBox(height: 8),
                Text(reason.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  children: [
                    _Stat(label: 'Durée', value: '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'),
                    _Stat(label: 'Ennemis vaincus', value: '${run.kills}'),
                    _Stat(label: 'Cartes', value: '${run.cards.length}'),
                  ],
                ),
                const SizedBox(height: 24),
                if (run.cards.isEmpty)
                  const Text('Aucune carte cette fois. Tue 10 ennemis ou trouve un coffre !',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))
                else
                  for (final c in run.cards) CardTile(card: c, isNew: freshIds.contains(c.id)),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Retour au menu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}
