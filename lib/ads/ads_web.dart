import 'package:flutter/widgets.dart';

import '../core/ads.dart';
import 'simulated_ad.dart';

Future<void> init() async {}

AdMode get mode => AdMode.simulated;

bool get simulated => true;

/// Vidéo simulée : aucune régie, donc aucun consentement à recueillir.
bool get privacyOptionsRequired => false;

Future<void> showPrivacyOptions() async {}

Future<bool> showRewarded(BuildContext context) => showSimulatedAd(context);
