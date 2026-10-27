import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../core/online_config.dart';
import '../online.dart';
import 'theme.dart';

/// Compte en ligne : état du serveur, connexion par e-mail, synchro de la collection.
class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key});

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  late final Future<bool> _ping = Online.ping();

  @override
  Widget build(BuildContext context) {
    final status = Online.config.status;
    return FutureBuilder<bool>(
      future: _ping,
      builder: (context, snap) {
        final (IconData icon, Color color, String text) = switch (status) {
          OnlineConfigStatus.ok when !snap.hasData => (Icons.cloud_sync, Colors.white60, 'Connexion au serveur…'),
          OnlineConfigStatus.ok when snap.data == true => (Icons.cloud_done, AppColors.teal, 'Serveur joignable'),
          OnlineConfigStatus.ok => (Icons.cloud_off, AppColors.coral, 'Serveur injoignable pour l\'instant'),
          _ => (Icons.cloud_off, Colors.white60, status.label),
        };
        return _Panel(children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          if (!Online.ready)
            const Text('Ta collection reste sur cet appareil.', style: TextStyle(color: Colors.white60, fontSize: 12))
          else
            ValueListenableBuilder<int>(
              valueListenable: Online.revision,
              builder: (context, _, __) => Online.user == null ? const _LoginForm() : const _AccountInfo(),
            ),
        ]);
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF3A2D86), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

const _small = TextStyle(color: Colors.white60, fontSize: 12);

InputDecoration _field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white60),
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );

/// Connexion sans mot de passe : on reçoit un e-mail avec un code (et un lien magique sur le web).
class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!isPlausibleEmail(_email.text)) {
      setState(() => _message = 'Adresse e-mail invalide.');
      return;
    }
    setState(() => _busy = true);
    final err = await Online.sendCode(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = err == null;
      _message = err;
    });
  }

  Future<void> _verify() async {
    if (!isPlausibleOtp(_code.text)) {
      setState(() => _message = 'Le code fait 6 chiffres.');
      return;
    }
    setState(() => _busy = true);
    final err = await Online.verifyCode(_email.text, _code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Connecte-toi pour sauvegarder ta collection en ligne et la retrouver sur tous tes appareils.',
          style: _small),
      const SizedBox(height: 10),
      TextField(
        controller: _email,
        enabled: !_codeSent && !_busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        style: const TextStyle(color: Colors.white),
        decoration: _field('Adresse e-mail', Icons.mail_outline),
        onSubmitted: (_) => _send(),
      ),
      if (_codeSent) ...[
        const SizedBox(height: 8),
        Text('E-mail envoyé à ${_email.text.trim()}. Ouvre-le '
            '${kIsWeb ? 'dans ce navigateur' : 'sur ce téléphone'} et touche le lien « Sign in » : '
            'tu seras connecté automatiquement. (S\'il contient un code, tu peux aussi le saisir ici.)',
            style: _small),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.bold),
          decoration: _field('Code (facultatif)', Icons.pin_outlined),
          onSubmitted: (_) => _verify(),
        ),
      ],
      if (_message != null) ...[
        const SizedBox(height: 8),
        Text(_message!, style: const TextStyle(color: AppColors.coral, fontSize: 12)),
      ],
      const SizedBox(height: 10),
      Row(children: [
        if (_codeSent)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _code.clear();
                      _message = null;
                    }),
            child: const Text('Changer d\'adresse', style: TextStyle(color: Colors.white70)),
          ),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: _busy ? null : (_codeSent ? _verify : _send),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_codeSent ? 'Valider' : 'Recevoir un code'),
        ),
      ]),
    ]);
  }
}

/// Compte connecté : adresse, code ami du serveur, état de la synchro.
class _AccountInfo extends StatelessWidget {
  const _AccountInfo();

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (Online.syncState) {
      SyncState.syncing => ('Synchronisation de la collection…', Colors.white70),
      SyncState.done => ('Collection sauvegardée en ligne (${Online.onlineCount} exemplaires)', AppColors.teal),
      SyncState.error => (Online.lastError ?? 'Erreur de synchronisation', AppColors.coral),
      SyncState.idle => ('Collection pas encore synchronisée', Colors.white70),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Connecté : ${Online.user?.email ?? ''}', style: const TextStyle(color: Colors.white)),
      if (Online.friendCode != null)
        Text('Code ami en ligne : ${Online.friendCode}', style: const TextStyle(color: AppColors.gold)),
      const SizedBox(height: 6),
      Text(text, style: TextStyle(color: color, fontSize: 12)),
      const SizedBox(height: 8),
      Row(children: [
        TextButton(
          onPressed: Online.signOut,
          child: const Text('Se déconnecter', style: TextStyle(color: Colors.white70)),
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: Online.syncState == SyncState.syncing ? null : Online.sync,
          icon: const Icon(Icons.sync),
          label: const Text('Synchroniser'),
        ),
      ]),
    ]);
  }
}
