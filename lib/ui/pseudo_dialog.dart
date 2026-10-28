import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../online.dart';
import 'theme.dart';

/// Fenêtre de choix du pseudo (enregistré sur l'appareil, et en ligne si connecté).
/// [first] : à la première connexion (retour de Clem du 28/10 : sans ça, « Explorateur » ajoutait
/// « Explorateur » en ami) ; le joueur doit alors choisir un vrai pseudo, sans pouvoir annuler.
Future<void> showPseudoDialog(BuildContext context, String current, {bool first = false}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: !first,
      builder: (_) => PopScope(canPop: !first, child: _PseudoDialog(current: current, first: first)),
    );

class _PseudoDialog extends StatefulWidget {
  const _PseudoDialog({required this.current, required this.first});
  final String current;
  final bool first;

  @override
  State<_PseudoDialog> createState() => _PseudoDialogState();
}

class _PseudoDialogState extends State<_PseudoDialog> {
  late final _ctrl = TextEditingController(text: widget.current == defaultPseudo ? '' : widget.current);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = chosenPseudoError(_ctrl.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _busy = true);
    final serverErr = await Online.setPseudo(_ctrl.text);
    if (!mounted) return;
    if (serverErr == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = serverErr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A1F66),
      title: Text(widget.first ? 'Choisis ton pseudo' : 'Ton pseudo', style: const TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.first)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('C\'est le nom que verront tes amis (classement, échanges). Tu pourras le changer '
                'plus tard en touchant ton nom dans le Profil.', style: TextStyle(color: Colors.white70)),
          ),
        TextField(
          controller: _ctrl,
          autofocus: true,
          maxLength: maxPseudoLength,
          enabled: !_busy,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ex. : Clem_Explo',
            hintStyle: const TextStyle(color: Colors.white38),
            errorText: _error,
            counterStyle: const TextStyle(color: Colors.white38),
          ),
          onSubmitted: (_) => _save(),
        ),
      ]),
      actions: [
        if (!widget.first)
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: _busy ? null : _save,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
