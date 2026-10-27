import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/economy.dart';
import '../core/places.dart';
import '../game/place.dart';
import 'theme.dart';
import 'widgets.dart';

/// Guide des points d'intérêt et des règles, avec les mêmes dessins que dans le jeu.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('Guide', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: const [
          SectionTitle('Le but'),
          _Entry(
            art: _Art(_ArtKind.cards),
            title: 'Trouve 3 cartes en 2 minutes',
            text: 'La run s\'arrête quand tu as 3 cartes, quand le temps est écoulé ou quand tu n\'as plus de vies. '
                'On gagne une carte en battant ${GameConfig.killsPerCard} ennemis, ou en découvrant un des lieux '
                'ci-dessous. Aucune boussole : explore !',
          ),
          SectionTitle('Les lieux'),
          _Entry(
            art: _Art(_ArtKind.chest),
            title: 'Coffre',
            text: 'Marche dessus pour l\'ouvrir : 1 carte et des pièces. Les coffres sont rares, souvent sur les '
                'hauteurs, et jamais tout près du départ.',
          ),
          _Entry(
            art: _Art(_ArtKind.rareChest),
            title: 'Coffre rare',
            text: 'Violet et lumineux, uniquement loin du point de départ. Meilleures chances d\'obtenir une '
                'carte rare, épique ou légendaire.',
          ),
          _Entry(
            art: _Art(_ArtKind.sanctuaryLocked),
            title: 'Sanctuaire (autel endormi)',
            text: 'Un autel de pierre avec un orbe éteint. Les points au-dessus = les gardiens encore en vie : '
                '4 ennemis postés tout autour. Bats-les tous…',
          ),
          _Entry(
            art: _Art(_ArtKind.sanctuaryAwake),
            title: 'Sanctuaire (éveillé)',
            text: '… l\'orbe s\'allume en doré. Marche alors sur l\'autel pour gagner une carte, avec plus de chances '
                'de rareté qu\'un coffre.',
          ),
          _Entry(
            art: _Art(_ArtKind.tower),
            title: 'Tour',
            text: 'Une pyramide de pierre lilas. Grimpe-la étage par étage en sautant (bouton SAUT) : le coffre '
                'est au sommet.',
          ),
          _Entry(
            art: _Art(_ArtKind.ruinClosed),
            title: 'Ruine (portail fermé)',
            text: 'Une arche de pierre ; les 3 points dessous = les pierres runiques à activer. Elles sont '
                'dispersées dans les environs et gardées par des ennemis.',
          ),
          _Entry(
            art: _Art(_ArtKind.rune),
            title: 'Pierre runique',
            text: 'Un disque gris marqué d\'un triangle. Marche dessus (sur le même étage) pour l\'allumer en bleu.',
          ),
          _Entry(
            art: _Art(_ArtKind.ruinOpen),
            title: 'Ruine (portail ouvert)',
            text: 'Les 3 runes allumées, le portail brille : entre dedans pour gagner une carte.',
          ),
          SectionTitle('Pièces'),
          _Entry(
            art: _Art(_ArtKind.coin),
            title: 'Pièces',
            text: 'Ramasse-les en passant dessus (parfois un tas de ${Economy.pileValue}). Chaque ennemi vaincu en '
                'donne ${Economy.coinsPerKill}, chaque lieu ouvert ${Economy.coinsPerPlace}. Dépense-les dans la '
                'Boutique : une énergie = une run de plus (${Economy.maxEnergyPurchasesPerDay} par jour au plus).',
          ),
          SectionTitle('Les ennemis'),
          _Entry(
            art: _Art(_ArtKind.melee),
            title: 'Corps à corps',
            text: 'Te fonce dessus. Quand un cercle blanc se resserre autour de lui, il va frapper : esquive !',
          ),
          _Entry(
            art: _Art(_ArtKind.ranged),
            title: 'Tireur',
            text: 'Garde ses distances et tire des projectiles. Les ennemis ne quittent jamais leur étage.',
          ),
          _Entry(
            art: _Art(_ArtKind.hearts),
            title: 'Vies',
            text: '3 vies (4 avec un compagnon Résistance). Si tu en as perdu une, chaque série de '
                '${GameConfig.killsPerLifeRegen} ennemis vaincus t\'en rend une.',
          ),
          SectionTitle('Les étages'),
          _Entry(
            art: _Art(_ArtKind.levels),
            title: 'Monter, descendre, frapper',
            text: 'Plus le sol est clair, plus il est haut. SAUT pour monter d\'un étage ; on redescend en '
                'marchant. Ton attaque touche aussi un ennemi un étage au-dessus ou en dessous.',
          ),
          SizedBox(height: 8),
          Text(
            'Clavier : ZQSD / WASD / flèches · Espace = saut · J = attaque · K = esquive',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.art, required this.title, required this.text});
  final Widget art;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF3A2D86), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: const Color(0xFF74BD6A), borderRadius: BorderRadius.circular(12)),
          child: art,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

enum _ArtKind {
  cards,
  chest,
  rareChest,
  sanctuaryLocked,
  sanctuaryAwake,
  tower,
  ruinClosed,
  rune,
  ruinOpen,
  coin,
  melee,
  ranged,
  hearts,
  levels,
}

class _Art extends StatelessWidget {
  const _Art(this.kind);
  final _ArtKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _ArtKind.cards:
        return const Icon(Icons.style, color: AppColors.gold, size: 40);
      case _ArtKind.hearts:
        return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.favorite, color: AppColors.coral, size: 20),
          Icon(Icons.favorite, color: AppColors.coral, size: 20),
          Icon(Icons.favorite_border, color: AppColors.coral, size: 20),
        ]);
      default:
        return CustomPaint(painter: _ArtPainter(kind));
    }
  }
}

/// Reprend les dessins du jeu, agrandis (×2).
class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);
  final _ArtKind kind;

  static final _fill = Paint();
  static final _outline = Paint()
    ..color = const Color(0xFF2B1A1A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(2);
    const c = Offset.zero;
    switch (kind) {
      case _ArtKind.chest:
        PlaceArt.draw(canvas, PlaceType.chest, c);
      case _ArtKind.rareChest:
        PlaceArt.draw(canvas, PlaceType.rareChest, c);
      case _ArtKind.sanctuaryLocked:
        PlaceArt.draw(canvas, PlaceType.sanctuary, c + const Offset(0, 3), unlocked: false, guardiansLeft: 4);
      case _ArtKind.sanctuaryAwake:
        PlaceArt.draw(canvas, PlaceType.sanctuary, c + const Offset(0, 3));
      case _ArtKind.ruinClosed:
        PlaceArt.draw(canvas, PlaceType.ruin, c - const Offset(0, 2), unlocked: false, runesLit: 1);
      case _ArtKind.ruinOpen:
        PlaceArt.draw(canvas, PlaceType.ruin, c - const Offset(0, 2), runesLit: 3);
      case _ArtKind.rune:
        PlaceArt.drawRune(canvas, c - const Offset(6, 0), lit: false);
        PlaceArt.drawRune(canvas, c + const Offset(8, 0), lit: true);
      case _ArtKind.tower:
        const colors = [Color(0xFF6F6890), Color(0xFF837BA6), Color(0xFF9890BA), Color(0xFFADA6CC)];
        for (var i = 0; i < colors.length; i++) {
          final half = 16.0 - i * 4;
          _fill.color = colors[i];
          canvas.drawRect(Rect.fromCenter(center: c, width: half * 2, height: half * 2), _fill);
        }
        canvas.save();
        canvas.scale(0.5);
        PlaceArt.draw(canvas, PlaceType.chest, c);
        canvas.restore();
      case _ArtKind.coin:
        for (final o in const [Offset(-6, 4), Offset(6, 4), Offset(0, -3)]) {
          _fill.color = const Color(0xFFD99A00);
          canvas.drawCircle(o, 6, _fill);
          _fill.color = const Color(0xFFFFC93C);
          canvas.drawCircle(o, 4.6, _fill);
        }
      case _ArtKind.melee:
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 20, height: 20), const Radius.circular(5));
        _fill.color = const Color(0xFFE84A5F);
        canvas.drawRRect(r, _fill);
        canvas.drawRRect(r, _outline);
        final ring = Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(c, 15, ring);
      case _ArtKind.ranged:
        final path = Path()
          ..moveTo(0, -12)
          ..lineTo(11, 0)
          ..lineTo(0, 12)
          ..lineTo(-11, 0)
          ..close();
        _fill.color = const Color(0xFFFF9F1C);
        canvas.drawPath(path, _fill);
        canvas.drawPath(path, _outline);
      case _ArtKind.levels:
        const colors = [Color(0xFF4F9A58), Color(0xFF74BD6A), Color(0xFF9BD57E), Color(0xFFD9C79A), Color(0xFFF4F2FA)];
        for (var i = 0; i < colors.length; i++) {
          _fill.color = colors[i];
          canvas.drawRect(Rect.fromLTWH(-17 + i * 7, 10 - i * 5.0, 7, 8 + i * 5.0), _fill);
        }
        _fill.color = const Color(0xFF7B5CFF);
        canvas.drawCircle(Offset(-6, 2 - 4 * math.sin(math.pi / 3)), 4, _fill);
      case _ArtKind.cards:
      case _ArtKind.hearts:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind;
}
