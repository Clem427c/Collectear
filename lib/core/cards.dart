import 'dart:convert';
import 'dart:math';

enum Rarity { commune, peuCommune, rare, epique, legendaire }

extension RarityInfo on Rarity {
  String get label => const ['Commune', 'Peu commune', 'Rare', 'Épique', 'Légendaire'][index];

  /// Probabilité d'obtention (exemple du GDD, à équilibrer en playtest).
  double get dropWeight => const [0.60, 0.25, 0.10, 0.04, 0.01][index];

  int get color => const [0xFFB0B0B0, 0xFF2EC4B6, 0xFF7B5CFF, 0xFFFF6B6B, 0xFFFFB627][index];
}

enum CardFamily { creature, hero }

/// Boost apporté par une carte choisie comme compagnon de run.
enum Boost { damage, speed, resistance, time, range }

extension BoostInfo on Boost {
  String get label => const ['Dégâts', 'Vitesse', 'Résistance', 'Temps', 'Portée'][index];
  String get description => const [
        'Un ennemi tombe en 2 coups au lieu de 3',
        'Déplacement plus rapide',
        '4 vies au lieu de 3',
        '+30 secondes au chrono',
        'Attaque les ennemis de plus loin',
      ][index];
}

class GameCard {
  const GameCard({
    required this.id,
    required this.name,
    required this.family,
    required this.rarity,
    required this.hp,
    required this.atk,
    required this.def,
    required this.boost,
  });

  final int id;
  final String name;
  final CardFamily family;
  final Rarity rarity;
  final int hp;
  final int atk;
  final int def;

  /// Boost fixe de la carte quand elle est compagnon (choisi selon son nom,
  /// voir tool/assign_boosts.py).
  final Boost boost;

  factory GameCard.fromJson(Map<String, dynamic> j) => GameCard(
        id: j['id'] as int,
        name: j['name'] as String,
        family: j['family'] == 'hero' ? CardFamily.hero : CardFamily.creature,
        rarity: Rarity.values[j['rarity'] as int],
        hp: j['hp'] as int,
        atk: j['atk'] as int,
        def: j['def'] as int,
        boost: Boost.values.byName(j['boost'] as String),
      );
}

/// Ensemble des cartes du jeu et tirage pondéré par rareté.
class CardPool {
  CardPool(List<GameCard> cards)
      : cards = List.unmodifiable(cards),
        _byRarity = {for (final r in Rarity.values) r: cards.where((c) => c.rarity == r).toList()};

  factory CardPool.fromJsonString(String source) {
    final list = (jsonDecode(source) as List).cast<Map<String, dynamic>>();
    return CardPool(list.map(GameCard.fromJson).toList());
  }

  final List<GameCard> cards;
  final Map<Rarity, List<GameCard>> _byRarity;

  GameCard? byId(int id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Tire une rareté. [luck] (0..1) déplace des chances des communes vers le haut.
  Rarity drawRarity(Random rng, {double luck = 0}) {
    final weights = Rarity.values.map((r) => r.dropWeight).toList();
    final shift = (luck.clamp(0.0, 1.0)) * 0.25;
    weights[0] -= shift;
    weights[1] += shift * 0.45;
    weights[2] += shift * 0.33;
    weights[3] += shift * 0.16;
    weights[4] += shift * 0.06;
    final total = weights.reduce((a, b) => a + b);
    var roll = rng.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return Rarity.values[i];
    }
    return Rarity.commune;
  }

  GameCard draw(Random rng, {double luck = 0}) {
    var rarity = drawRarity(rng, luck: luck);
    while (_byRarity[rarity]!.isEmpty && rarity.index > 0) {
      rarity = Rarity.values[rarity.index - 1];
    }
    final list = _byRarity[rarity]!;
    return list[rng.nextInt(list.length)];
  }
}
