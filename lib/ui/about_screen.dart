import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/about.dart';
import 'theme.dart';
import 'widgets.dart';

/// « À propos » (⚙ Paramètres → Aide) : version du jeu, politique de confidentialité, suppression du compte,
/// licences des logiciels utilisés (exigé par plusieurs licences libres).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Ouvre [url] dans le navigateur ; si c'est impossible, copie l'adresse et le dit.
  static Future<void> openLink(BuildContext context, String url) async {
    if (!isSafeLink(url)) return;
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible d\'ouvrir le lien : adresse copiée ($url)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('À propos', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.style, color: AppColors.gold, size: 56),
          const SizedBox(height: 8),
          const Text('Collectear',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          GestureDetector(
            // Appui long : copie la version (pratique pour signaler un problème).
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: 'Collectear ${versionLabel()}'));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Version copiée')));
            },
            child: Text('Version ${versionLabel()}',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 6),
          const Text('Explore, combats et collectionne 300 cartes.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SectionTitle('Liens'),
          _Box(children: [
            for (final l in kAboutLinks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.open_in_new, color: AppColors.gold),
                title: Text(l.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text(l.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () => openLink(context, l.url),
              ),
          ]),
          const SectionTitle('Logiciels'),
          _Box(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description, color: AppColors.gold),
              title: const Text('Licences des logiciels', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Flutter, Flame, Supabase… et leurs licences',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Collectear',
                applicationVersion: versionLabel(),
              ),
            ),
          ]),
        ],
      ),
    );
  }
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
