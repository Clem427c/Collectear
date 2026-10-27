import 'dart:math' as math;

import 'config.dart';
import 'noise.dart';

/// Économie des pièces (retour de Clem du 27/10).
///
/// Les pièces se ramassent dans le monde (bien plus courantes que les cartes) et en battant des
/// ennemis. Elles servent dans la Boutique, d'abord pour acheter des énergies (= runs en plus).
///
/// PROVISOIRE (équilibrage à valider en jeu) : une run rapporte environ 30 à 50 pièces.
/// 1re énergie du jour = 60 pièces, puis +40 à chaque achat (60, 100, 140, 180, 220) :
/// les 5 énergies d'un jour coûtent 700 pièces, soit à peu près 15 à 20 runs de récolte.
/// Un joueur qui fait ses 10 runs gratuites peut donc s'offrir 2 ou 3 runs de plus, pas 5 chaque jour.
class Economy {
  Economy._();

  /// Valeur d'une pièce ramassée au sol, et d'un petit tas de pièces.
  static const int coinValue = 1;
  static const int pileValue = 5;

  /// Pièces gagnées pour chaque ennemi vaincu.
  static const int coinsPerKill = 2;

  /// Pièces bonus quand on ouvre un lieu (coffre, sanctuaire, tour, ruine).
  static const int coinsPerPlace = 10;

  /// Pièces au sol par chunk : 0 à 3 pièces isolées, et parfois un tas.
  static const int maxCoinsPerChunk = 3;
  static const double pileChance = 0.12;

  /// Énergies achetables avec des pièces, par jour.
  static const int maxEnergyPurchasesPerDay = 5;
  static const int energyBasePrice = 60;
  static const int energyPriceStep = 40;

  /// Prix de la prochaine énergie, ou null si la limite du jour est atteinte.
  static int? energyPrice(int boughtToday) {
    if (boughtToday >= maxEnergyPurchasesPerDay) return null;
    return energyBasePrice + energyPriceStep * boughtToday;
  }

  /// Pièces au sol d'un chunk : liste de (case x, case y, valeur). Déterministe (seed du monde).
  /// Aucune pièce sur le chunk de départ.
  static List<(int, int, int)> coinsForChunk(int worldSeed, int cx, int cy) {
    if (cx == 0 && cy == 0) return const [];
    final rng = math.Random(hash3(worldSeed ^ 0xC01, cx, cy));
    const n = GameConfig.chunkTiles;
    final out = <(int, int, int)>[];
    final used = <(int, int)>{};
    final count = rng.nextInt(maxCoinsPerChunk + 1);
    for (var i = 0; i < count; i++) {
      final t = (cx * n + rng.nextInt(n), cy * n + rng.nextInt(n));
      if (used.add(t)) out.add((t.$1, t.$2, coinValue));
    }
    if (rng.nextDouble() < pileChance) {
      final t = (cx * n + rng.nextInt(n), cy * n + rng.nextInt(n));
      if (used.add(t)) out.add((t.$1, t.$2, pileValue));
    }
    return out;
  }
}
