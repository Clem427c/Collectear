/// Recherche de cartes par nom (bestiaire, échanges, profil d'un ami) et filtre par rareté.
library;

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

/// Cartes qui correspondent à la recherche [query] et, si elle est donnée, à la rareté [rarity].
/// L'ordre d'origine est conservé.
List<GameCard> filterCards(Iterable<GameCard> cards, {String query = '', Rarity? rarity}) => [
      for (final c in cards)
        if ((rarity == null || c.rarity == rarity) && cardMatchesQuery(c, query)) c,
    ];

/// Bestiaire : une carte pas encore obtenue s'affiche « ??? ». PROVISOIRE : la recherche par nom
/// ne la trouve donc pas (sinon on devinerait les noms des cartes cachées) ; par numéro, si.
bool bestiaryMatches(GameCard card, String query, {required bool owned}) =>
    cardMatchesQuery(card, query) && (owned || foldForSearch(query).isEmpty || isNumberQuery(query));
