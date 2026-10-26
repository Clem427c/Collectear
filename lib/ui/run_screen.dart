import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/cards.dart';
import '../core/config.dart';
import '../core/run_state.dart';
import '../game/collectear_game.dart';
import '../game/sfx.dart';
import '../app_data.dart';
import 'recap_screen.dart';
import 'theme.dart';
import 'widgets.dart';

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
    _game.countdown.dispose();
    _game.hurtPulse.dispose();
    _game.cardEvent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<CollectearGame>(
        game: _game,
        overlayBuilderMap: {
          'hud': (context, game) => _Hud(game: game, companion: widget.companion),
          'fx': (context, game) => _Fx(game: game, companion: widget.companion),
        },
        initialActiveOverlays: const ['hud', 'fx'],
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
                    StatefulBuilder(
                      builder: (context, setLocal) => IconButton.filledTonal(
                        onPressed: () => setLocal(() => Sfx.enabled = !Sfx.enabled),
                        icon: Icon(Sfx.enabled ? Icons.volume_up : Icons.volume_off),
                        tooltip: 'Son',
                      ),
                    ),
                    const SizedBox(width: 4),
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


/// Effets plein écran : compte à rebours, flash de dégâts, carte obtenue.
class _Fx extends StatelessWidget {
  const _Fx({required this.game, this.companion});
  final CollectearGame game;
  final GameCard? companion;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        // Flash rouge sur les bords quand le joueur est touché.
        ValueListenableBuilder<int>(
          valueListenable: game.hurtPulse,
          builder: (context, pulse, _) => pulse == 0
              ? const SizedBox.shrink()
              : TweenAnimationBuilder<double>(
                  key: ValueKey(pulse),
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, v, _) => Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.1,
                        colors: [Colors.transparent, AppColors.coral.withValues(alpha: 0.55 * v)],
                        stops: const [0.6, 1],
                      ),
                    ),
                  ),
                ),
        ),
        // Compte à rebours de départ.
        ValueListenableBuilder<int?>(
          valueListenable: game.countdown,
          builder: (context, n, _) {
            if (n == null) return const SizedBox.shrink();
            return Container(
              color: n > 0 ? Colors.black.withValues(alpha: 0.35) : Colors.transparent,
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(n),
                  tween: Tween(begin: 1.8, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Text(
                    n > 0 ? '$n' : 'GO !',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 4))],
                    ),
                  ),
                ),
                if (n > 0) ...[
                  const SizedBox(height: 8),
                  const Text('Trouve 3 cartes en 2 minutes',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (companion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Compagnon : ${companion!.name} · ${companion!.boost.label}',
                          style: TextStyle(color: rarityColor(companion!.rarity), fontWeight: FontWeight.bold)),
                    ),
                ],
              ]),
            );
          },
        ),
        // Carte obtenue.
        ValueListenableBuilder<GameCard?>(
          valueListenable: game.cardEvent,
          builder: (context, card, _) {
            if (card == null) return const SizedBox.shrink();
            return _CardPopup(key: ObjectKey(card), card: card, onDone: () {
              if (game.cardEvent.value == card) game.cardEvent.value = null;
            });
          },
        ),
      ]),
    );
  }
}

class _CardPopup extends StatefulWidget {
  const _CardPopup({super.key, required this.card, required this.onDone});
  final GameCard card;
  final VoidCallback onDone;

  @override
  State<_CardPopup> createState() => _CardPopupState();
}

class _CardPopupState extends State<_CardPopup> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final appear = Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
        final leave = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - leave,
          child: Align(
            alignment: Alignment(0, -0.15 - leave * 0.6),
            child: Transform.scale(scale: 0.3 + 0.7 * appear - leave * 0.4, child: child),
          ),
        );
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('NOUVELLE CARTE !',
            style: TextStyle(
              color: rarityColor(widget.card.rarity),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
            )),
        const SizedBox(height: 8),
        SizedBox(width: 150, child: CardView(card: widget.card)),
      ]),
    );
  }
}
