import 'package:flutter/material.dart';

import '../app_data.dart';
import '../game/sfx.dart';
import '../online.dart';
import 'account_panel.dart';
import 'guide_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Paramètres (roue crantée en haut à droite) : son, vibrations, compte en ligne, guide.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.data});
  final AppData data;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _volume = widget.data.settings.volume;
  late bool _haptics = widget.data.settings.haptics;

  @override
  Widget build(BuildContext context) {
    final settings = widget.data.settings;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle('Son'),
          _Box(children: [
            Row(children: [
              Icon(_volume == 0 ? Icons.volume_off : Icons.volume_up, color: AppColors.gold),
              Expanded(
                child: Slider(
                  value: _volume,
                  divisions: 10,
                  label: '${(_volume * 100).round()} %',
                  activeColor: AppColors.gold,
                  onChanged: (v) {
                    setState(() => _volume = v);
                    Sfx.volumeLevel = v;
                  },
                  onChangeEnd: (v) async {
                    await settings.setVolume(v);
                    Sfx.play('coin');
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${(_volume * 100).round()} %', style: const TextStyle(color: Colors.white70)),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _haptics,
              activeThumbColor: AppColors.gold,
              title: const Text('Vibrations', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Quand on frappe, qu\'on est touché ou qu\'on gagne une carte',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onChanged: (v) async {
                setState(() => _haptics = v);
                Sfx.hapticsEnabled = v;
                await settings.setHaptics(v);
              },
            ),
          ]),
          const SectionTitle('Compte'),
          if (Online.ready || Online.config.isUsable) const AccountPanel() else const _OfflineNote(),
          const SectionTitle('Aide'),
          _Box(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book, color: AppColors.gold),
              title: const Text('Guide des lieux et du jeu', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Coffres, sanctuaires, tours, ruines, pièces, ennemis…',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GuideScreen())),
            ),
          ]),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) => const _Box(children: [
        Text('Mode hors ligne : ta collection reste sur cet appareil.', style: TextStyle(color: Colors.white70)),
      ]);
}

class _Box extends StatelessWidget {
  const _Box({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF3A2D86), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// Fenêtre « Connecte-toi » proposée une seule fois, au premier lancement.
/// Se ferme toute seule dès que la connexion réussit (y compris via le lien de l'e-mail).
Future<void> showFirstLaunchLogin(BuildContext context, AppData data) async {
  if (!Online.ready || Online.user != null || data.settings.loginPromptShown) return;
  await data.settings.markLoginPromptShown();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => ValueListenableBuilder<int>(
      valueListenable: Online.revision,
      builder: (ctx, _, __) {
        final connected = Online.user != null;
        return AlertDialog(
          backgroundColor: AppColors.night,
          title: Text(connected ? 'Bienvenue !' : 'Sauvegarde ta collection',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: connected
                  ? Text('Connecté : ${Online.user?.email ?? ''}. Ta collection est sauvegardée en ligne.',
                      style: const TextStyle(color: Colors.white70))
                  : const Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        'Connecte-toi avec ton adresse e-mail pour retrouver tes cartes sur tous tes appareils. '
                        'Pas de mot de passe : tu reçois un lien par e-mail.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 12),
                      AccountPanel(),
                    ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(connected ? 'C\'est parti !' : 'Plus tard (Paramètres ⚙)',
                  style: const TextStyle(color: AppColors.gold)),
            ),
          ],
        );
      },
    ),
  );
}
