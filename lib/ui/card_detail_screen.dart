import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_data.dart';
import '../core/cards.dart';
import '../core/variants.dart';
import '../online.dart';
import 'theme.dart';
import 'widgets.dart';

/// Échelle des barres de stats (un peu au-dessus du maximum du jeu : 197 PV, 36 ATQ, 34 DEF, +4 %).
const _maxHp = 210.0;
const _maxAtk = 40.0;
const _maxDef = 40.0;

/// Ouvre la fiche détaillée d'une carte en plein écran.
/// [variantSeeds] : exemplaires possédés (on peut les faire défiler) ; [initialSeed] : celui à montrer d'abord.
Future<void> openCardDetail(
  BuildContext context,
  GameCard card, {
  List<int> variantSeeds = const [],
  int? initialSeed,
  bool isCompanion = false,
  VoidCallback? onEquip,
  bool canFavorite = false,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => CardDetailScreen(
      card: card,
      variantSeeds: variantSeeds,
      initialSeed: initialSeed,
      isCompanion: isCompanion,
      onEquip: onEquip,
      canFavorite: canFavorite,
    ),
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
  ));
}

/// Écran de carte détaillé : grande illustration (teintée selon la variante), stats, boost et variante.
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.card,
    this.variantSeeds = const [],
    this.initialSeed,
    this.isCompanion = false,
    this.onEquip,
    this.canFavorite = false,
  });
  final GameCard card;
  final List<int> variantSeeds;
  final int? initialSeed;
  final bool isCompanion;
  final VoidCallback? onEquip;

  /// Exemplaires du joueur : bouton étoile pour mettre l'exemplaire affiché en favori.
  final bool canFavorite;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> with TickerProviderStateMixin {
  late final List<CardInstance?> _items;
  late final PageController _pages;
  late final AnimationController _float;
  late final AnimationController _spin;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final instances = [for (final s in widget.variantSeeds) CardInstance(widget.card, s)]
      ..sort((a, b) => b.variant.prestige.compareTo(a.variant.prestige));
    _items = instances.isEmpty ? [null] : instances;
    if (widget.initialSeed != null) {
      final i = _items.indexWhere((e) => e?.variantSeed == widget.initialSeed);
      if (i >= 0) _index = i;
    }
    _pages = PageController(initialPage: _index, viewportFraction: 0.86);
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    _pages.dispose();
    _float.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final color = rarityColor(card.rarity);
    final current = _items[_index];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 1.1,
            colors: [Color.lerp(color, AppColors.ink, 0.35)!, AppColors.ink.withValues(alpha: 0.97)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (widget.canFavorite && current != null) _favoriteButton(card, current.variantSeed),
                    Text('N° ${card.id.toString().padLeft(3, '0')}',
                        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                  ]),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        SizedBox(
                          height: 300,
                          child: PageView.builder(
                            controller: _pages,
                            itemCount: _items.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (_, i) => _illustration(_items[i], active: i == _index),
                          ),
                        ),
                        if (_items.length > 1) _dots(color),
                        const SizedBox(height: 8),
                        _header(card, color),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(children: [
                            _StatBar(
                              icon: Icons.favorite,
                              label: 'PV',
                              value: current?.hp ?? card.hp,
                              max: _maxHp,
                              color: AppColors.coral,
                              delta: current == null ? null : Variant.deltaPercent(current.variant.hpMult),
                            ),
                            _StatBar(
                              icon: Icons.flash_on,
                              label: 'ATQ',
                              value: current?.atk ?? card.atk,
                              max: _maxAtk,
                              color: AppColors.gold,
                              delta: current == null ? null : Variant.deltaPercent(current.variant.atkMult),
                            ),
                            _StatBar(
                              icon: Icons.shield_outlined,
                              label: 'DEF',
                              value: current?.def ?? card.def,
                              max: _maxDef,
                              color: AppColors.teal,
                              delta: current == null ? null : Variant.deltaPercent(current.variant.defMult),
                            ),
                            const SizedBox(height: 16),
                            _BoostPanel(boost: card.boost),
                            if (current != null) ...[
                              const SizedBox(height: 12),
                              _VariantPanel(variant: current.variant, index: _index + 1, total: _items.length),
                            ],
                            if (widget.onEquip != null) ...[
                              const SizedBox(height: 20),
                              ChunkyButton(
                                label: widget.isCompanion ? 'Déjà équipé' : 'Équiper comme compagnon',
                                fontSize: 16,
                                onPressed: widget.isCompanion
                                    ? null
                                    : () {
                                        widget.onEquip!();
                                        Navigator.of(context).pop();
                                      },
                              ),
                            ],
                          ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Étoile : met l'exemplaire affiché en favori (il ne pourra plus être échangé) ou l'en retire.
  Widget _favoriteButton(GameCard card, int seed) {
    return ValueListenableBuilder<int>(
      valueListenable: Online.revision,
      builder: (context, _, __) {
        final fav = Online.isFavorite(card.id, seed);
        return IconButton(
          tooltip: fav ? 'Retirer des favoris' : 'Mettre en favori',
          icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: fav ? AppColors.gold : Colors.white70, size: 30),
          onPressed: () async {
            final err = await Online.setFavorite(card.id, seed, !fav);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(err ??
                    (fav
                        ? 'Retiré des favoris : cet exemplaire peut de nouveau être échangé.'
                        : 'En favori : cet exemplaire ne peut plus être échangé ni demandé.')),
              ));
          },
        );
      },
    );
  }

  Widget _header(GameCard card, Color color) {
    return Column(children: [
      Text(
        card.name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)],
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Pill(text: card.rarity.label.toUpperCase(), color: color),
        const SizedBox(width: 8),
        _Pill(text: card.family == CardFamily.hero ? 'HÉROS' : 'CRÉATURE', color: AppColors.night),
      ]),
    ]);
  }

  Widget _dots(Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < math.min(_items.length, 12); i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 16 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _index ? color : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  /// Grande illustration qui flotte doucement et fait un tour sur elle-même quand on la touche.
  Widget _illustration(CardInstance? inst, {required bool active}) {
    final card = widget.card;
    final hasArt = Illustrations.available.contains(card.id);
    Widget art;
    if (inst != null) {
      art = VariantEmblem(card: card, variant: inst.variant, size: 260);
    } else {
      art = Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: rarityGradient(card.rarity)),
        padding: const EdgeInsets.all(12),
        child: hasArt
            ? Image.asset(Illustrations.path(card.id), fit: BoxFit.contain)
            : Icon(card.family == CardFamily.hero ? Icons.person : Icons.pets, size: 120, color: Colors.white),
      );
    }
    return AnimatedScale(
      scale: active ? 1 : 0.82,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTap: active ? () => _spin.forward(from: 0) : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_float, _spin]),
          builder: (_, child) {
            final t = Curves.easeInOut.transform(_float.value);
            final turn = active ? Curves.easeOutCubic.transform(_spin.value) * 2 * math.pi : 0.0;
            return Transform.translate(
              offset: Offset(0, -8 * t),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(turn),
                child: child,
              ),
            );
          },
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: rarityColor(card.rarity).withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: art,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white70),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.delta,
  });
  final IconData icon;
  final String label;
  final int value;
  final double max;
  final Color color;

  /// Écart de la variante par rapport à l'espèce, en % (null = vue de l'espèce).
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        SizedBox(width: 34, child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / max).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 12,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        SizedBox(
          width: 44,
          child: d == null
              ? null
              : Text(
                  d == 0 ? '=' : (d > 0 ? '+$d %' : '−${-d} %'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: d > 0 ? const Color(0xFF6BE36B) : (d < 0 ? AppColors.coral : Colors.white54),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ]),
    );
  }
}

class _BoostPanel extends StatelessWidget {
  const _BoostPanel({required this.boost});
  final Boost boost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.ink,
          child: Icon(boostIcon(boost), color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Boost compagnon : ${boost.label}',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
            Text(boost.description, style: const TextStyle(color: Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

class _VariantPanel extends StatelessWidget {
  const _VariantPanel({required this.variant, required this.index, required this.total});
  final Variant variant;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final special = variant.prestige > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: special ? AppColors.gold : Colors.white24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              total > 1 ? 'Exemplaire $index / $total' : 'Mon exemplaire',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
          for (var i = 1; i <= 5; i++)
            Icon(i <= variant.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18, color: AppColors.gold),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _Tag(text: variant.code, color: AppColors.night),
          _Tag(text: 'Motif : ${variant.pattern.label}', color: AppColors.night),
          if (variant.finish != VariantFinish.normal) _Tag(text: variant.finish.label, color: AppColors.gold, dark: true),
          if (variant.shiny) const _Tag(text: '✦ Shiny', color: AppColors.violet),
        ]),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.dark = false});
  final String text;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(color: dark ? AppColors.ink : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
