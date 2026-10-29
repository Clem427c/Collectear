import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Vidéo récompensée SIMULÉE (web et PC, où AdMob n'existe pas) : 5 secondes d'attente, puis la
/// récompense. PROVISOIRE : sert à tester le parcours sans téléphone ; à retirer (ou à remplacer
/// par une vraie régie web) avant la mise en ligne publique.
Future<bool> showSimulatedAd(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const _SimulatedAd(),
  );
  return ok ?? false;
}

class _SimulatedAd extends StatefulWidget {
  const _SimulatedAd();

  @override
  State<_SimulatedAd> createState() => _SimulatedAdState();
}

class _SimulatedAdState extends State<_SimulatedAd> {
  static const _seconds = 5;
  int _left = _seconds;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left <= 0;
    return AlertDialog(
      backgroundColor: AppColors.night,
      title: const Text('Publicité (test)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.ondemand_video, color: AppColors.gold, size: 64),
        const SizedBox(height: 12),
        Text(
          done ? 'Vidéo terminée : récompense gagnée !' : 'Une vraie vidéo passera ici sur téléphone… $_left s',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: 1 - _left / _seconds,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
        ),
      ]),
      actions: [
        if (!done)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Fermer (sans récompense)'),
          ),
        if (done)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Récupérer'),
          ),
      ],
    );
  }
}
