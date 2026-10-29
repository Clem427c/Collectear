import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads.dart';
import '../ui/widgets.dart';
import 'simulated_ad.dart';

/// Vraies vidéos AdMob sur Android (identifiants de test tant que Clem n'a pas son compte).
/// iOS viendra avec l'App Store (identifiants à créer) : vidéo simulée en attendant.
bool get _native => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get simulated => !_native;

bool _initialized = false;
RewardedAd? _ready;
Future<void>? _loading;

Future<void> init() async {
  if (!_native || _initialized) return;
  try {
    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(_load());
  } catch (e) {
    debugPrint('AdMob : initialisation impossible : $e');
  }
}

/// Charge une vidéo en réserve (une seule à la fois).
Future<void> _load() {
  if (_ready != null || !_initialized) return Future.value();
  return _loading ??= () async {
    final c = Completer<void>();
    try {
      await RewardedAd.load(
        adUnitId: AdIds.rewardedAndroid,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ready = ad;
            if (!c.isCompleted) c.complete();
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMob : vidéo non chargée : $error');
            if (!c.isCompleted) c.complete();
          },
        ),
      );
      await c.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    } catch (e) {
      debugPrint('AdMob : $e');
    } finally {
      _loading = null;
    }
  }();
}

Future<bool> showRewarded(BuildContext context) async {
  if (!_native) return showSimulatedAd(context);
  if (!_initialized) await init();
  if (_ready == null) {
    // Pas encore de vidéo en réserve : petite attente, puis on abandonne proprement.
    if (!context.mounted) return false;
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));
    await _load();
    nav.pop();
  }
  final ad = _ready;
  _ready = null;
  if (ad == null) {
    if (context.mounted) showPrototypeSnack(context, 'Aucune vidéo disponible pour le moment. Réessaie plus tard.');
    unawaited(_load());
    return false;
  }
  final done = Completer<bool>();
  var earned = false;
  ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      if (!done.isCompleted) done.complete(earned);
      unawaited(_load());
    },
    onAdFailedToShowFullScreenContent: (ad, error) {
      debugPrint('AdMob : vidéo non affichée : $error');
      ad.dispose();
      if (!done.isCompleted) done.complete(false);
      unawaited(_load());
    },
  );
  try {
    await ad.show(onUserEarnedReward: (shown, reward) => earned = true);
  } catch (e) {
    debugPrint('AdMob : $e');
    if (!done.isCompleted) done.complete(false);
  }
  return done.future;
}
