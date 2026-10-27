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
    'life.wav', 'chest.wav', 'card.wav', 'tick.wav', 'go.wav', 'run_end.wav', 'coin.wav', 'hurry.wav',
  ];

  /// Un petit groupe de lecteurs réutilisés par son (AudioPool). Avant, chaque son créait un
  /// nouveau lecteur jamais libéré : sur un vieux téléphone, le jeu ralentissait au fil de la run.
  static final Map<String, AudioPool> _pools = {};
  static final Map<String, int> _lastPlayMs = {};
  static final Stopwatch _clock = Stopwatch()..start();

  /// Sons fréquents : plus de lecteurs simultanés.
  static const _busy = {'hit': 4, 'swing': 3, 'shoot': 4, 'coin': 3, 'enemy_die': 3};

  static Future<void> preload() async {
    if (_loaded) return;
    _loaded = true;
    for (final f in files) {
      final name = f.replaceAll('.wav', '');
      try {
        _pools[name] = await FlameAudio.createPool(f, minPlayers: 1, maxPlayers: _busy[name] ?? 2);
      } catch (_) {
        // Pas de son si le chargement échoue (ex. navigateur sans audio) : le jeu continue.
      }
    }
  }

  static void play(String name, {double volume = 0.7}) {
    if (!enabled || volumeLevel <= 0) return;
    final pool = _pools[name];
    if (pool == null) return;
    // Le même son au plus toutes les 50 ms (une rafale de coups ne sature pas l'audio).
    final now = _clock.elapsedMilliseconds;
    if (now - (_lastPlayMs[name] ?? -1000) < 50) return;
    _lastPlayMs[name] = now;
    unawaited(pool.start(volume: (volume * volumeLevel).clamp(0.0, 1.0)).then((_) {}, onError: (_) {}));
  }

  /// Volume général (0 à 1), réglé dans les Paramètres.
  static double volumeLevel = 1.0;

  /// Vibrations activées (Paramètres).
  static bool hapticsEnabled = true;

  static void haptic(HapticStrength s) {
    if (!hapticsEnabled) return;
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
