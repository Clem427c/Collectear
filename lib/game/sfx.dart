import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

/// Effets sonores (fichiers générés par tool/gen_sfx.py) et vibrations.
class Sfx {
  Sfx._();

  static bool enabled = true;
  static bool _loaded = false;

  static const files = [
    'swing.wav', 'hit.wav', 'enemy_die.wav', 'hurt.wav', 'jump.wav', 'dodge.wav', 'shoot.wav',
    'life.wav', 'chest.wav', 'card.wav', 'tick.wav', 'go.wav', 'run_end.wav',
  ];

  static Future<void> preload() async {
    if (_loaded) return;
    try {
      await FlameAudio.audioCache.loadAll(files);
      _loaded = true;
    } catch (_) {
      // Pas de son si le chargement échoue (ex. navigateur sans audio) : le jeu continue.
    }
  }

  static void play(String name, {double volume = 0.7}) {
    if (!enabled) return;
    unawaited(FlameAudio.play('$name.wav', volume: volume).then((_) {}, onError: (_) {}));
  }

  static void haptic(HapticStrength s) {
    switch (s) {
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

enum HapticStrength { light, medium, heavy }
