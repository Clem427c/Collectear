import 'dart:math' as math;

import 'cards.dart';

/// Motif appliqué sur l'illustration d'une variante.
enum VariantPattern { none, stripes, spots, stars, rings }

extension VariantPatternInfo on VariantPattern {
  String get label => const ['Uni', 'Rayures', 'Taches', 'Étoiles', 'Anneaux'][index];
}

/// Finition spéciale (très rare).
enum VariantFinish { normal, golden, crystal, shadow }

extension VariantFinishInfo on VariantFinish {
  String get label => const ['', 'Dorée', 'Cristal', 'Ombre'][index];
}

/// Variante procédurale d'une carte : même espèce, apparence et stats légèrement différentes.
/// Entièrement déterminée par une seed, donc stockable sous forme d'un simple entier.
class Variant {
  Variant._({
    required this.seed,
    required this.hue,
    required this.pattern,
    required this.shiny,
    required this.finish,
    required this.hpMult,
    required this.atkMult,
    required this.defMult,
  });

  /// Probabilités (sur 1).
  static const double shinyChance = 1 / 40;
  static const double goldenChance = 1 / 100;
  static const double crystalChance = 1 / 150;
  static const double shadowChance = 1 / 150;

  /// Écart maximal des stats par rapport à l'espèce (±4 %). À ±4 %, même dans le pire cas,
  /// une variante ne dépasse jamais la puissance d'une carte de rareté supérieure.
  static const double statSpread = 0.04;

  factory Variant.fromSeed(int seed) {
    final rng = math.Random(seed);
    final hue = rng.nextDouble() * 360;
    final p = rng.nextDouble();
    final pattern = p < 0.40
        ? VariantPattern.none
        : p < 0.60
            ? VariantPattern.stripes
            : p < 0.78
                ? VariantPattern.spots
                : p < 0.90
                    ? VariantPattern.rings
                    : VariantPattern.stars;
    final shiny = rng.nextDouble() < shinyChance;
    final f = rng.nextDouble();
    final finish = f < goldenChance
        ? VariantFinish.golden
        : f < goldenChance + crystalChance
            ? VariantFinish.crystal
            : f < goldenChance + crystalChance + shadowChance
                ? VariantFinish.shadow
                : VariantFinish.normal;
    double mult() => 1 + (rng.nextDouble() * 2 - 1) * statSpread;
    return Variant._(
      seed: seed,
      hue: hue,
      pattern: pattern,
      shiny: shiny,
      finish: finish,
      hpMult: mult(),
      atkMult: mult(),
      defMult: mult(),
    );
  }

  final int seed;

  /// Teinte de l'illustration (0..360°).
  final double hue;
  final VariantPattern pattern;
  final bool shiny;
  final VariantFinish finish;
  final double hpMult;
  final double atkMult;
  final double defMult;

  /// Plus la variante est spéciale, plus elle est recherchée (0 = ordinaire).
  int get prestige => (shiny ? 2 : 0) + (finish != VariantFinish.normal ? 3 : 0);

  /// Qualité des stats de 0 (les trois au minimum, −4 %) à 1 (les trois au maximum, +4 %).
  double get quality {
    final avg = (hpMult + atkMult + defMult) / 3;
    return ((avg - (1 - statSpread)) / (2 * statSpread)).clamp(0.0, 1.0);
  }

  /// Étoiles de l'exemplaire (1 à 5) = rareté de son APPARENCE, du plus courant au plus rare.
  /// Retour de Clem du 28/10 : avant, les étoiles mesuraient seulement les stats (±4 %), si bien
  /// qu'un Shiny pouvait avoir moins d'étoiles qu'un exemplaire uni ; incompréhensible.
  /// Les stats restent affichées à part (écart de chaque stat et moyenne, [statsPercent]).
  ///   1 ★ uni, rayures, taches (≈ 78 %)   2 ★ motif étoiles ou anneaux (≈ 22 %)
  ///   3 ★ Shiny (1/40)                      4 ★ finition Dorée, Cristal ou Ombre (≈ 1/43)
  ///   5 ★ finition + Shiny (≈ 1/1700)
  // PROVISOIRE : paliers proposés par Claude, à valider par Clem (ROADMAP, Questions).
  int get stars {
    final special = finish != VariantFinish.normal;
    if (special && shiny) return 5;
    if (special) return 4;
    if (shiny) return 3;
    if (pattern == VariantPattern.stars || pattern == VariantPattern.rings) return 2;
    return 1;
  }

  /// Nom de la rareté de l'apparence, selon les étoiles.
  String get rarityLabel => const ['Courant', 'Peu courant', 'Rare', 'Très rare', 'Exceptionnel'][stars - 1];

  /// Écart moyen des trois stats par rapport à l'espèce, en pourcentage arrondi (−4 à +4).
  int get statsPercent => deltaPercent((hpMult + atkMult + defMult) / 3);

  /// Écart d'un multiplicateur en pourcentage arrondi (ex. 1.031 → 3, 0.962 → −4).
  static int deltaPercent(double mult) => ((mult - 1) * 100).round();

  /// Code court lisible (ex. « #4F2A »), unique à 1 chance sur 65 536.
  String get code => '#${(seed & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';

  String get label {
    final parts = <String>[
      if (finish != VariantFinish.normal) finish.label,
      if (shiny) 'Shiny',
    ];
    return parts.isEmpty ? 'Variante $code' : '${parts.join(' ')} $code';
  }
}

/// Un exemplaire possédé : une espèce + une variante.
class CardInstance {
  CardInstance(this.card, this.variantSeed) : variant = Variant.fromSeed(variantSeed);

  final GameCard card;
  final int variantSeed;
  final Variant variant;

  int get hp => (card.hp * variant.hpMult).round();
  int get atk => math.max(1, (card.atk * variant.atkMult).round());
  int get def => math.max(1, (card.def * variant.defMult).round());
}
