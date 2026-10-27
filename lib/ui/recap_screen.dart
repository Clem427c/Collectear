import 'package:flutter/material.dart';

import '../core/cards.dart';
import '../core/run_state.dart';
import 'card_detail_screen.dart';
import 'widgets.dart';
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
                    _Stat(label: 'Pièces', value: '+${run.coins}'),
                  ],
                ),
                const SizedBox(height: 24),
                if (run.cards.isEmpty)
                  const Text('Aucune carte cette fois. Tue 10 ennemis ou trouve un coffre !',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in run.cards)
                        SizedBox(
                          width: 130,
                          child: CardView(
                            card: c.card,
                            instance: c,
                            isNew: freshIds.contains(c.card.id),
                            onTap: () => openCardDetail(context, c.card, variantSeeds: [c.variantSeed]),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 32),
                ChunkyButton(label: 'CONTINUER', fontSize: 20, onPressed: () => Navigator.of(context).pop()),
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
