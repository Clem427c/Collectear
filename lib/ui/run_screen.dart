import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/cards.dart';
import '../core/config.dart';
import '../core/run_state.dart';
import '../game/collectear_game.dart';
import '../app_data.dart';
import 'recap_screen.dart';
import 'theme.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.data, this.companion});
  final AppData data;
  final GameCard? companion;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  late final CollectearGame _game;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _game = CollectearGame(
      pool: widget.data.pool,
      rules: RunRules(boost: widget.companion?.boost),
      seed: math.Random().nextInt(1 << 31),
      onRunEnd: _onRunEnd,
    );
  }

  Future<void> _onRunEnd(RunState run) async {
    if (_ended || !mounted) return;
    _ended = true;
    final col = widget.data.collection;
    final fresh = await col.addAll(run.cards.map((c) => c.id));
    await col.recordRunResult(kills: run.kills, cards: run.cards.length);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => RecapScreen(run: run, freshIds: fresh, companion: widget.companion),
    ));
  }

  @override
  void dispose() {
    _game.hud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<CollectearGame>(
        game: _game,
        overlayBuilderMap: {
          'hud': (context, game) => _Hud(game: game, companion: widget.companion),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, this.companion});
  final CollectearGame game;
  final GameCard? companion;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<HudData>(
        valueListenable: game.hud,
        builder: (context, h, _) {
          final m = h.remaining ~/ 60;
          final s = (h.remaining % 60).toString().padLeft(2, '0');
          final low = h.remaining <= 15;
          return Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    _Pill(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < h.maxHits; i++)
                        Icon(i < h.hitsLeft ? Icons.favorite : Icons.favorite_border,
                            color: AppColors.coral, size: 20),
                    ])),
                    const SizedBox(width: 8),
                    _Pill(child: Text('⚔ ${h.killsTowardCard}/${GameConfig.killsPerCard}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    const Spacer(),
                    _Pill(
                      child: Text('$m:$s',
                          style: TextStyle(
                              color: low ? AppColors.coral : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    _Pill(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < GameConfig.maxCardsPerRun; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(i < h.cards ? Icons.style : Icons.crop_portrait,
                              color: AppColors.gold, size: 20),
                        ),
                    ])),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: game.quit,
                      icon: const Icon(Icons.close),
                      tooltip: 'Abandonner la run',
                    ),
                  ],
                ),
              ),
              if (companion != null)
                Positioned(
                  top: 60,
                  left: 8,
                  child: _Pill(
                    child: Text('${companion!.name} · ${companion!.boost.label}',
                        style: TextStyle(color: rarityColor(companion!.rarity), fontSize: 12)),
                  ),
                ),
              if (h.message != null)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _Pill(
                      child: Text(h.message!, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
