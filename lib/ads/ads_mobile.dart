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

bool _initialized = false;
bool _canRequestAds = false;
bool _privacyOptions = false;
RewardedAd? _ready;
Future<void>? _loading;
Future<void>? _starting;

AdMode get mode => AdConsent.mode(nativeAds: _native, canRequestAds: _canRequestAds, testIds: AdIds.usingTestIds);

bool get simulated => mode == AdMode.simulated;

bool get privacyOptionsRequired => _native && _privacyOptions;

/// Démarrage : d'abord le consentement RGPD (UMP), ensuite seulement le SDK AdMob et la 1re vidéo.
Future<void> init() {
  if (!_native || _initialized) return Future.value();
  return _starting ??= () async {
    try {
      await _gatherConsent();
      if (!_canRequestAds) {
        debugPrint('AdMob : pas de consentement, aucune pub demandée (mode : $mode)');
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      unawaited(_load());
    } catch (e) {
      debugPrint('AdMob : initialisation impossible : $e');
    } finally {
      _starting = null;
    }
  }();
}

/// Met à jour l'état du consentement et montre le formulaire de Google s'il est requis
/// (premier lancement en Europe, ou choix expiré). Ne lève jamais d'exception.
Future<void> _gatherConsent() async {
  final done = Completer<void>();
  void finish([FormError? error]) {
    if (error != null) debugPrint('UMP : ${error.errorCode} ${error.message}');
    if (!done.isCompleted) done.complete();
  }

  try {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired(finish),
      finish,
    );
    // Le formulaire peut rester ouvert longtemps : pas de délai si le joueur est en train de choisir.
    await done.future;
  } catch (e) {
    debugPrint('UMP : $e');
  }
  await _refreshConsent();
}

Future<void> _refreshConsent() async {
  try {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyOptions = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  } catch (e) {
    debugPrint('UMP : $e');
  }
}

/// Rouvre le formulaire de Google pour changer son choix (⚙ Paramètres → Publicités).
Future<void> showPrivacyOptions() async {
  if (!_native) return;
  if (!_privacyOptions) {
    // Pas de formulaire « modifier mes choix » proposé : on refait la demande de consentement complète.
    await init();
    return;
  }
  final done = Completer<void>();
  try {
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('UMP : ${error.errorCode} ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    await done.future;
  } catch (e) {
    debugPrint('UMP : $e');
  }
  await _refreshConsent();
  if (_canRequestAds && !_initialized) {
    await init();
  } else if (!_canRequestAds) {
    _ready?.dispose();
    _ready = null;
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
  if (!_initialized) await init();
  if (!context.mounted) return false;
  switch (mode) {
    case AdMode.simulated:
      return showSimulatedAd(context);
    case AdMode.unavailable:
      showPrototypeSnack(context, 'Vidéos indisponibles sans ton choix de confidentialité : ⚙ Paramètres → Publicités.');
      return false;
    case AdMode.real:
      break;
  }
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
