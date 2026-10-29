import 'package:flutter/widgets.dart';

import 'simulated_ad.dart';

Future<void> init() async {}

bool get simulated => true;

Future<bool> showRewarded(BuildContext context) => showSimulatedAd(context);
