/// Recherche de cartes par nom (bestiaire, échanges, profil d'un ami) et filtre par rareté.
library;

import 'biomes.dart';
import 'cards.dart';

const Map<String, String> _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'û': 'u', 'ü': 'u', 'ú': 'u', 'ù': 'u',
  'ÿ': 'y', 'ý': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  '’': "'",
};

/// Texte ramené à une forme comparable : minuscules, sans accents, espaces simples.
/// « Gaïa la Forgeronne » → « gaia la forgeronne ».
String foldForSearch(String s) {
  final out = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    out.write(_accents[c] ?? c);
  }
  return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// La recherche est-elle un numéro de carte (« 29 », « 029 », « #29 ») ?
bool isNumberQuery(String query) => RegExp(r'^#?\d+$').hasMatch(foldForSearch(query));

/// La carte correspond-elle à la recherche ?
/// - recherche vide : oui ;
/// - un nombre (« 29 », « 029 ») : la carte de ce numéro ;
/// - sinon chaque mot tapé doit apparaître dans le nom, dans n'importe quel ordre, sans tenir
///   compte des majuscules ni des accents (« forgeronne gaia » trouve « Gaïa la Forgeronne »).
bool cardMatchesQuery(GameCard card, String query) {
  final q = foldForSearch(query);
  if (q.isEmpty) return true;
  if (isNumberQuery(q)) return card.id == int.parse(q.replaceFirst('#', ''));
  final name = foldForSearch(card.name);
  return q.split(' ').every(name.contains);
}

/// Cartes qui correspondent à la recherche [query] et, s'ils sont donnés, à la rareté [rarity]
/// et au biome d'origine [biome]. L'ordre d'origine est conservé.
List<GameCard> filterCards(Iterable<GameCard> cards, {String query = '', Rarity? rarity, Biome? biome}) => [
      for (final c in cards)
        if ((rarity == null || c.rarity == rarity) && (biome == null || c.biome == biome) && cardMatchesQuery(c, query))
          c,
    ];

/// Progression du bestiaire dans un biome (GDD diapo 11 : « chaque biome a ses espèces »).
class BiomeProgress {
  const BiomeProgress(this.biome, this.owned, this.total);
  final Biome biome;

  /// Espèces de ce biome déjà obtenues.
  final int owned;

  /// Espèces de ce biome dans le bestiaire.
  final int total;

  bool get complete => total > 0 && owned >= total;
}

/// Espèces obtenues / espèces existantes pour chaque biome, dans l'ordre de [Biome.values].
/// [ownedIds] : numéros des cartes possédées. Les cartes sans biome ne comptent nulle part.
List<BiomeProgress> biomeProgress(Iterable<GameCard> cards, Set<int> ownedIds) => [
      for (final b in Biome.values)
        BiomeProgress(
          b,
          cards.where((c) => c.biome == b && ownedIds.contains(c.id)).length,
          cards.where((c) => c.biome == b).length,
        ),
    ];

/// Bestiaire : une carte pas encore obtenue s'affiche « ??? ». PROVISOIRE : la recherche par nom
/// ne la trouve donc pas (sinon on devinerait les noms des cartes cachées) ; par numéro, si.
bool bestiaryMatches(GameCard card, String query, {required bool owned}) =>
    cardMatchesQuery(card, query) && (owned || foldForSearch(query).isEmpty || isNumberQuery(query));
