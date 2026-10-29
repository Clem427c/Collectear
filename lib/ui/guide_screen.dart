import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/economy.dart';
import '../core/places.dart';
import '../core/social.dart' show maxTradeSide;
import '../game/place.dart';
import 'theme.dart';
import 'variant_gallery_screen.dart';
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
            text: 'Un autel de pierre avec un orbe éteint. Les points dorés au-dessus = les gardiens encore en '
                'vie : 4 ennemis d\'élite postés tout autour, reliés à l\'autel par un fil doré. Bats-les tous…',
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
                'est sur la plate-forme du sommet, un dernier saut plus haut.',
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
                'Boutique : une énergie = une run de plus (${Economy.maxEnergyPurchasesPerDay} par jour au plus). '
                'Plus aucune run ? Une vidéo t\'en offre une (${GameConfig.adBonusRunsPerDay} par jour au plus).',
          ),
          SectionTitle('Les ennemis'),
          _Entry(
            art: _Art(_ArtKind.melee),
            title: 'Gobelin (corps à corps)',
            text: 'Te fonce dessus. Quand un cercle blanc se resserre autour de lui, il va frapper : esquive !',
          ),
          _Entry(
            art: _Art(_ArtKind.ranged),
            title: 'Diablotin (tireur)',
            text: 'Garde ses distances et lance des boules de feu. Les ennemis ne quittent jamais leur étage.',
          ),
          _Entry(
            art: _Art(_ArtKind.guards),
            title: 'Gardiens (élite)',
            text: 'Golem et mage noir, avec un anneau doré au sol : ils défendent un sanctuaire ou une pierre '
                'runique et restent près de leur poste. Mêmes points de vie que les autres.',
          ),
          _Entry(
            art: _Art(_ArtKind.hearts),
            title: 'Vies',
            text: '3 vies (4 avec un compagnon Résistance). Si tu en as perdu une, chaque série de '
                '${GameConfig.killsPerLifeRegen} ennemis vaincus t\'en rend une. Tombé au combat ? Une courte '
                'vidéo (facultative) te fait revenir avec ${GameConfig.reviveLives} vie, une fois par run.',
          ),
          SectionTitle('Les étages'),
          _Entry(
            art: _Art(_ArtKind.levels),
            title: 'Monter, descendre, frapper',
            text: 'Plus le sol est clair, plus il est haut. SAUT pour monter d\'un étage ; on redescend en '
                'marchant. Ton attaque touche aussi un ennemi un étage au-dessus ou en dessous. Collé à un '
                'ennemi (ou sur lui), ton coup le touche quelle que soit la direction.',
          ),
          SectionTitle('Tes cartes'),
          _Entry(
            art: _IconArt(Icons.style),
            title: 'Chaque carte est unique',
            text: 'Deux exemplaires d\'une même carte ne sont jamais identiques : couleur, motif (uni, rayures, '
                'taches, anneaux, étoiles), parfois un éclat Shiny ou une finition spéciale, et des stats '
                'légèrement différentes. Touche une carte du bestiaire pour voir et faire défiler tes exemplaires.',
          ),
          _Entry(
            art: _StarsArt(),
            title: 'Étoiles : rareté de l\'apparence',
            text: '★ uni, rayures ou taches (le plus courant)\n'
                '★★ motif étoiles ou anneaux\n'
                '★★★ Shiny (1 sur 40)\n'
                '★★★★ finition Dorée, Cristal ou Ombre\n'
                '★★★★★ finition + Shiny (exceptionnel)\n'
                'Les étoiles ne disent rien de la force de la carte.',
          ),
          _GalleryButton(),
          _Entry(
            art: _IconArt(Icons.bar_chart_rounded, color: AppColors.teal),
            title: 'Stats de l\'exemplaire',
            text: 'PV, ATQ et DEF varient de −4 % à +4 % autour de ceux de l\'espèce. Sur la fiche, chaque stat '
                'affiche son écart, et l\'étiquette « Stats » donne la moyenne : en vert au-dessus de la normale, '
                'en rouge en dessous. Même à +4 %, une carte ne dépasse jamais une carte de rareté supérieure.',
          ),
          _Entry(
            art: _IconArt(Icons.star_rounded),
            title: 'Favoris',
            text: 'Touche l\'étoile en haut de la fiche pour mettre un exemplaire en favori (étoile dorée dans le '
                'coin de la carte). Un favori ne peut être ni proposé ni demandé dans un échange tant que tu ne '
                'l\'as pas retiré des favoris. Le mettre en favori annule les échanges en attente qui le concernent.',
          ),
          _Entry(
            art: _IconArt(Icons.swap_horiz_rounded, color: AppColors.teal),
            title: 'Échanges entre amis',
            text: 'Onglet Social : ajoute un ami avec son code ami, puis propose-lui de 1 à $maxTradeSide cartes '
                'contre 1 à $maxTradeSide des siennes, sans restriction de rareté. Les cartes changent de main '
                'quand il accepte.',
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

/// Ouvre la galerie : une carte dans ses 10 apparences.
class _GalleryButton extends StatelessWidget {
  const _GalleryButton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ChunkyButton(
          label: 'Voir toutes les variantes',
          icon: Icons.auto_awesome,
          fontSize: 16,
          color: AppColors.violet,
          textColor: Colors.white,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const VariantGalleryScreen())),
        ),
      );
}

/// Dessin d'une entrée sans image du jeu : une icône sur fond sombre.
class _IconArt extends StatelessWidget {
  const _IconArt(this.icon, {this.color = AppColors.gold});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Icon(icon, color: color, size: 40)),
      );
}

/// Les étoiles des exemplaires, comme sur la fiche d'une carte (3 sur 5 : un Shiny).
class _StarsArt extends StatelessWidget {
  const _StarsArt();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Wrap(alignment: WrapAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= 3 ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: AppColors.gold),
          ]),
        ),
      );
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
  guards,
  hearts,
  levels,
}

class _Art extends StatelessWidget {
  const _Art(this.kind);
  final _ArtKind kind;

  /// Images générées (assets/images/decors) ; repli sur les dessins vectoriels si elles manquent.
  static const _assets = {
    _ArtKind.chest: ['place_coffre'],
    _ArtKind.rareChest: ['place_coffre_rare'],
    _ArtKind.sanctuaryLocked: ['place_sanctuaire'],
    _ArtKind.sanctuaryAwake: ['place_sanctuaire_eveille'],
    _ArtKind.tower: ['place_sommet_tour'],
    _ArtKind.ruinClosed: ['place_ruine'],
    _ArtKind.ruinOpen: ['place_ruine_ouverte'],
    _ArtKind.rune: ['place_rune', 'place_rune_active'],
    _ArtKind.coin: ['item_tas_pieces'],
    _ArtKind.melee: ['ennemi_cac'],
    _ArtKind.ranged: ['ennemi_distance'],
    _ArtKind.guards: ['ennemi_cac_elite', 'ennemi_distance_elite'],
  };

  @override
  Widget build(BuildContext context) {
    final assets = _assets[kind];
    if (assets != null) {
      final fallback = CustomPaint(painter: _ArtPainter(kind));
      Widget art = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final a in assets)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/images/decors/$a.png',
                  fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback),
            ),
          ),
      ]);
      if (kind == _ArtKind.sanctuaryLocked) {
        art = Stack(children: [
          Positioned.fill(child: art),
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 4; i++)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.circle, size: 8, color: AppColors.gold)),
            ]),
          ),
        ]);
      }
      return art;
    }
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
          final half = const [18.0, 14.0, 10.0, 7.0][i]; // sommet large (3×3 cases en jeu)
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
      case _ArtKind.guards:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind;
}
