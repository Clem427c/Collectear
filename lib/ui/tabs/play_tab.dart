import 'package:flutter/material.dart';

import '../../app_data.dart';
import '../../core/cards.dart';
import '../../core/config.dart';
import '../run_screen.dart';
import '../theme.dart';
import '../widgets.dart';

/// Onglet central : lancer une run et équiper son compagnon.
class PlayTab extends StatelessWidget {
  const PlayTab({super.key, required this.data, required this.onChanged});
  final AppData data;
  final VoidCallback onChanged;

  Future<void> _startRun(BuildContext context) async {
    final col = data.collection;
    if (col.runsLeftToday <= 0) return;
    await col.registerRun();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RunScreen(data: data, companion: data.companion),
    ));
    onChanged();
  }

  Future<void> _pickCompanion(BuildContext context) async {
    final owned = data.ownedCards;
    if (owned.isEmpty) {
      showPrototypeSnack(context, 'Gagne ta première carte en run pour choisir un compagnon.');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choisis ton compagnon',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, -1),
              icon: const Icon(Icons.close),
              label: const Text('Partir sans compagnon'),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.72,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: owned.length,
                itemBuilder: (_, i) => CardView(card: owned[i], onTap: () => Navigator.pop(ctx, owned[i].id)),
              ),
            ),
          ]),
        ),
      ),
    );
    if (picked == null) return;
    await data.collection.setCompanion(picked == -1 ? null : picked);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final col = data.collection;
    final companion = data.companion;
    final runsLeft = col.runsLeftToday;
    final total = data.pool.cards.length;
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Progress(owned: col.distinctCount, total: total),
                  const SizedBox(height: 16),
                  const Text('COMPAGNON DE RUN',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _pickCompanion(context),
                    child: SizedBox(
                      width: 170,
                      child: companion != null ? CardView(card: companion) : const _EmptySlot(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (companion != null)
                    _BoostChip(boost: companion.boost)
                  else
                    const Text('Touchez pour équiper un compagnon', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: runsLeft > 0
                        ? ChunkyButton(
                            label: 'JOUER',
                            icon: Icons.play_arrow_rounded,
                            fontSize: 28,
                            onPressed: () => _startRun(context),
                          )
                        : ChunkyButton(
                            label: col.nextEnergyPrice == null
                                ? 'REVIENS DEMAIN'
                                : 'ÉNERGIE · ${col.nextEnergyPrice} pièces',
                            icon: col.nextEnergyPrice == null ? Icons.bedtime : Icons.bolt,
                            fontSize: 20,
                            onPressed: col.canBuyEnergy
                                ? () async {
                                    await col.buyEnergy();
                                    onChanged();
                                  }
                                : null,
                          ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    // Outil de test : appui long pour remettre le compteur de runs à zéro.
                    onLongPress: () async {
                      await col.resetRunsToday();
                      onChanged();
                    },
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < GameConfig.runsPerDay; i++)
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.bolt, size: 18, color: i < runsLeft ? AppColors.gold : Colors.white24),
                        ),
                    ]),
                  ),
                  // Il manque des énergies sans être à zéro : achat possible aussi d'ici.
                  if (runsLeft > 0 && col.energyMissing && col.nextEnergyPrice != null)
                    TextButton.icon(
                      onPressed: col.canBuyEnergy
                          ? () async {
                              await col.buyEnergy();
                              onChanged();
                            }
                          : null,
                      icon: const Icon(Icons.bolt, size: 16, color: AppColors.gold),
                      label: Text('+1 énergie · ${col.nextEnergyPrice} pièces',
                          style: TextStyle(color: col.canBuyEnergy ? AppColors.gold : Colors.white38, fontSize: 12)),
                    ),
                  Text('$runsLeft / ${GameConfig.runsPerDay} runs aujourd\'hui'
                      '${col.energyBoughtToday > 0 ? ' (+${col.energyBoughtToday} achetée${col.energyBoughtToday > 1 ? 's' : ''})' : ''}'
                      ' · ${col.coins} pièces',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 16),
                  const Text(
                    'Clavier : ZQSD / WASD / flèches · Espace = saut · J = attaque · K = esquive',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.owned, required this.total});
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        const Icon(Icons.style, color: AppColors.gold, size: 18),
        const SizedBox(width: 6),
        const Text('Bestiaire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('$owned / $total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : owned / total,
          minHeight: 10,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
        ),
      ),
    ]);
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.add, color: Colors.white38, size: 48),
      ),
    );
  }
}

class _BoostChip extends StatelessWidget {
  const _BoostChip({required this.boost});
  final Boost boost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(boostIcon(boost), color: AppColors.gold, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text('${boost.label} : ${boost.description}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
