import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/text.dart' show TextPaint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cards.dart';
import '../core/config.dart';
import '../core/run_state.dart';
import '../core/terrain.dart';
import 'chest.dart';
import 'enemy.dart';
import 'player.dart';
import 'spawner.dart';
import 'terrain_component.dart';

/// Données affichées par le HUD Flutter (overlay).
class HudData {
  const HudData({
    required this.remaining,
    required this.hitsLeft,
    required this.maxHits,
    required this.killsTowardCard,
    required this.cards,
    required this.message,
  });

  final int remaining;
  final int hitsLeft;
  final int maxHits;
  final int killsTowardCard;
  final int cards;
  final String? message;
}

class CollectearGame extends FlameGame with KeyboardEvents {
  CollectearGame({
    required this.pool,
    required this.rules,
    required this.seed,
    required this.onRunEnd,
  })  : terrain = Terrain(seed),
        run = RunState(rules),
        _rng = math.Random(seed ^ 0x5bd1e995);

  final CardPool pool;
  final RunRules rules;
  final int seed;
  final void Function(RunState run) onRunEnd;
  final Terrain terrain;
  final RunState run;
  final math.Random _rng;

  late final Player player;
  late final Spawner spawner;
  late final JoystickComponent joystick;

  final Vector2 _keyboardMove = Vector2.zero();
  final ValueNotifier<HudData> hud = ValueNotifier(
    const HudData(remaining: 120, hitsLeft: 3, maxHits: 3, killsTowardCard: 0, cards: 0, message: null),
  );
  String? _message;
  double _messageTime = 0;
  bool _endNotified = false;

  @override
  Color backgroundColor() => const Color(0xFF4F9A58);

  @override
  Future<void> onLoad() async {
    world.add(TerrainComponent());
    player = Player()..position = Vector2.all(GameConfig.tileSize / 2);
    world.add(player);
    spawner = Spawner();
    world.add(spawner);
    camera.follow(player);
    _addControls();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // ~11 cases sur le plus petit côté de l'écran.
    camera.viewfinder.zoom = math.max(0.5, size.x < size.y ? size.x : size.y) / (GameConfig.tileSize * 11);
  }

  void _addControls() {
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 24, paint: Paint()..color = const Color(0xCCFFFFFF)),
      background: CircleComponent(radius: 60, paint: Paint()..color = const Color(0x551B1440)),
      margin: const EdgeInsets.only(left: 36, bottom: 44),
    );
    camera.viewport.add(joystick);
    camera.viewport.add(_button('ATQ', 40, const Color(0xFFFF6B6B), const EdgeInsets.only(right: 40, bottom: 60),
        () => player.attack()));
    camera.viewport.add(_button('SAUT', 30, const Color(0xFF7B5CFF), const EdgeInsets.only(right: 130, bottom: 40),
        () => player.jump()));
    camera.viewport.add(_button('ESQ', 30, const Color(0xFF2EC4B6), const EdgeInsets.only(right: 60, bottom: 150),
        () => player.dodge()));
  }

  HudButtonComponent _button(String label, double radius, Color color, EdgeInsets margin, VoidCallback onPressed) {
    PositionComponent face(double alpha) {
      final circle = CircleComponent(radius: radius, paint: Paint()..color = color.withValues(alpha: alpha));
      circle.add(TextComponent(
        text: label,
        anchor: Anchor.center,
        position: Vector2.all(radius),
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ));
      return circle;
    }

    return HudButtonComponent(
      button: face(0.75),
      buttonDown: face(1),
      margin: margin,
      onPressed: onPressed,
    );
  }

  /// Direction de déplacement : joystick tactile, sinon clavier.
  Vector2 get moveInput {
    final j = joystick.relativeDelta;
    if (j.length2 > 0.0001) return j;
    if (_keyboardMove.length2 > 0) return _keyboardMove.normalized();
    return Vector2.zero();
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool any(List<LogicalKeyboardKey> keys) => keys.any(keysPressed.contains);
    _keyboardMove.setZero();
    if (any([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyQ])) _keyboardMove.x -= 1;
    if (any([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD])) _keyboardMove.x += 1;
    if (any([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyZ])) _keyboardMove.y -= 1;
    if (any([LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS])) _keyboardMove.y += 1;

    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space) player.jump();
      if (k == LogicalKeyboardKey.keyJ || k == LogicalKeyboardKey.enter) player.attack();
      if (k == LogicalKeyboardKey.keyK || k == LogicalKeyboardKey.shiftLeft) player.dodge();
    }
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);
    run.tick(dt);
    if (_messageTime > 0) {
      _messageTime -= dt;
      if (_messageTime <= 0) _message = null;
    }
    _pushHud();
    if (run.isOver && !_endNotified) {
      _endNotified = true;
      pauseEngine();
      Future<void>.delayed(const Duration(milliseconds: 300), () => onRunEnd(run));
    }
  }

  void _pushHud() {
    final next = HudData(
      remaining: run.remaining.ceil(),
      hitsLeft: run.hitsLeft,
      maxHits: rules.playerHitsToDie,
      killsTowardCard: run.killsTowardNextCard,
      cards: run.cards.length,
      message: _message,
    );
    final cur = hud.value;
    if (cur.remaining != next.remaining ||
        cur.hitsLeft != next.hitsLeft ||
        cur.maxHits != next.maxHits ||
        cur.killsTowardCard != next.killsTowardCard ||
        cur.cards != next.cards ||
        cur.message != next.message) {
      hud.value = next;
    }
  }

  void _toast(String text) {
    _message = text;
    _messageTime = 2.5;
  }

  /// Chance de rareté plus élevée en s'éloignant du point de départ.
  double get _luck {
    final tiles = player.position.length / GameConfig.tileSize;
    return (tiles / 150).clamp(0.0, 1.0);
  }

  void _giveCard({double bonusLuck = 0}) {
    final card = pool.draw(_rng, luck: _luck + bonusLuck);
    run.addCard(card);
    _toast('Carte obtenue : ${card.name} (${card.rarity.label})');
  }

  void enemyKilled(Enemy enemy) {
    spawner.consumed.add(enemy.spawnId);
    final before = run.livesRegained;
    final card = run.registerKill();
    if (run.livesRegained > before) _toast('+1 vie !');
    if (card) _giveCard();
  }

  void chestOpened(Chest chest) {
    spawner.consumed.add(chest.spawnId);
    _giveCard(bonusLuck: 0.15);
  }

  void playerHit() {
    final dead = run.playerHit();
    if (!dead) _toast('Aïe ! Encore ${run.hitsLeft} coup${run.hitsLeft > 1 ? 's' : ''} et c\'est fini');
  }

  void quit() => run.quit();
}
