import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../core/cards.dart';
import '../core/sharing.dart';
import '../core/variants.dart' show CardInstance;
import '../online.dart';
import 'theme.dart';
import 'widgets.dart';

/// « Partager ses plus belles trouvailles » (GDD diapo 12) : aperçu de l'image d'un exemplaire, puis
/// envoi par la feuille de partage du téléphone (WhatsApp, Messages…). Sur un navigateur qui ne sait
/// pas partager d'image (ordinateur), l'image est téléchargée.
Future<void> openShareCard(BuildContext context, CardInstance inst) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ShareDialog(inst: inst),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.inst});
  final CardInstance inst;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    String? error;
    // Position du bouton (iPad) lue avant les attentes, tant que le contexte est sûr.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final ro = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (ro == null) throw StateError('aperçu absent');
      final image = await ro.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('image vide');
      final name = shareFileName(widget.inst);
      final file = XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: name);
      await SharePlus.instance.share(ShareParams(
        text: shareMessage(widget.inst),
        files: [file],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ));
    } catch (e) {
      error = kIsWeb
          ? 'Ce navigateur ne sait pas partager d\'image. Essaie depuis ton téléphone.'
          : 'Le partage n\'a pas marché ($e).';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        FittedBox(
          child: RepaintBoundary(key: _boundary, child: ShareCardImage(inst: widget.inst, pseudo: Online.pseudo)),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
            onPressed: _busy ? null : _share,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      ]),
    );
  }
}

/// Image partagée (360 × 480, exportée en ×3) : illustration de la variante, nom, rareté,
/// apparence en étoiles, stats, pseudo de celui qui l'a trouvée et adresse du jeu.
class ShareCardImage extends StatelessWidget {
  const ShareCardImage({super.key, required this.inst, required this.pseudo});
  final CardInstance inst;
  final String pseudo;

  @override
  Widget build(BuildContext context) {
    final card = inst.card;
    final v = inst.variant;
    final color = rarityColor(card.rarity);
    final pct = v.statsPercent;
    const white = TextStyle(color: Colors.white, decoration: TextDecoration.none);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 360,
        height: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 4),
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.0,
            colors: [Color.lerp(color, AppColors.ink, 0.30)!, AppColors.ink],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(children: [
          Row(children: [
            Text('COLLECTEAR',
                style: white.copyWith(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.gold)),
            const Spacer(),
            Text('N° ${card.id.toString().padLeft(3, '0')}',
                style: white.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 36, spreadRadius: 4),
                ]),
                child: VariantEmblem(card: card, variant: v, size: 230, animate: false),
              ),
            ),
          ),
          Text(card.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: white.copyWith(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip(card.rarity.label.toUpperCase(), color),
            const SizedBox(width: 6),
            _chip(card.family == CardFamily.hero ? 'HÉROS' : 'CRÉATURE', AppColors.night),
          ]),
          const SizedBox(height: 8),
          Text('${starsText(v.stars)}  ${appearanceText(v)}',
              style: white.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gold)),
          const SizedBox(height: 2),
          Text(
            '${pct == 0 ? 'Stats moyennes' : 'Stats ${pct > 0 ? '+' : '−'}${pct.abs()} %'} · ${v.code}',
            style: white.copyWith(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text('Trouvée par $pseudo', style: white.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
          Text('clem427c.github.io/Collectear', style: white.copyWith(fontSize: 11, color: Colors.white54)),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
      );
}
