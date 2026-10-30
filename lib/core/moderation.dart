// Filtre des gros mots dans les pseudos.
//
// PROVISOIRE : liste courte (français + anglais), vérifiée seulement par l'appli (le serveur
// accepte encore n'importe quel pseudo de 1 à 24 caractères). Voir « Questions pour Clem ».
//
// Le pseudo est d'abord ramené à une forme simple : minuscules, sans accents, chiffres et
// symboles « leet » remplacés par des lettres (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a, $→s),
// lettres répétées réduites à une seule (« connnnard » → « conard »). Ainsi « C0NN4RD »,
// « S.a.l.o.p.e » ou « Pûtain » sont reconnus.
//
// Deux sortes de mots :
// - [_anywhere] : refusés même collés à d'autres lettres (« xXconnardXx »), car ils
//   n'apparaissent dans aucun mot courant ;
// - [_wholeWord] : refusés seulement comme mot entier (ou tout le pseudo collé), parce qu'ils se
//   cachent dans des mots innocents : « pute » dans « computer », « bite » dans « habite »,
//   « nique » dans « technique », « cul » dans « culture », « con » dans « Conan »,
//   « nigga » dans « nigaud », « negro » dans « Montenegro »…
// Attention : un mot à lettres doublées se réduit (« boobs » → « bobs », « kkk » → « k ») : vérifier
// que sa forme réduite n'est pas un mot innocent avant de l'ajouter (sinon « Bobs » serait refusé).

/// Mots refusés partout, même collés à d'autres lettres.
const List<String> _anywhere = [
  // Français
  'connard', 'connasse', 'salope', 'salaud', 'encule', 'enculer', 'putain', 'batard',
  'enfoire', 'branleur', 'branlette', 'pouffiasse', 'niquetamere', 'tamereenstring',
  'fdp', 'filsdepute', 'ntm', 'pedophile', 'bougnoul', 'youpin', 'sodomi',
  // Anglais
  'fuck', 'motherf', 'bitch', 'asshole', 'faggot', 'whore', 'pussy', 'blowjob',
  'dickhead', 'bullshit',
  // Haine
  'hitler', 'nazi', 'heilh',
];

/// Mots refusés seulement comme mot entier (ou quand tout le pseudo collé vaut ce mot).
const List<String> _wholeWord = [
  // Français
  'con', 'pute', 'putes', 'couille', 'couilles', 'bite', 'bites', 'nique', 'niquer', 'cul', 'chatte', 'merde',
  'pd', 'tg', 'suce', 'sucer', 'pedo', 'negre', 'negro', 'negros', 'teub', 'zob', 'chier', 'gouine', 'tapette',
  // Anglais
  'shit', 'dick', 'nigga', 'niggas', 'cock', 'cunt', 'fag', 'slut', 'porn', 'porno', 'sex', 'sexe', 'penis', 'anal',
  'cum', 'tits', 'wtf', 'stfu',
];

const Map<String, String> _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'û': 'u', 'ü': 'u', 'ú': 'u', 'ù': 'u',
  'ÿ': 'y', 'ý': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
};

const Map<String, String> _leet = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', r'$': 's', '!': 'i',
};

/// Forme simplifiée d'un mot : minuscules, sans accents, « leet » remplacé, lettres
/// répétées réduites. Les caractères autres que lettres et chiffres sont gardés tels quels
/// (ils servent de séparateurs dans [_tokens]).
String simplifyForModeration(String s) {
  final out = StringBuffer();
  String? last;
  for (final rune in s.toLowerCase().runes) {
    var c = String.fromCharCode(rune);
    c = _accents[c] ?? _leet[c] ?? c;
    for (final ch in c.split('')) {
      if (ch == last && RegExp('[a-z]').hasMatch(ch)) continue;
      out.write(ch);
      last = ch;
    }
  }
  return out.toString();
}

/// Mots du pseudo simplifié (séparés par tout ce qui n'est pas une lettre ou un chiffre).
List<String> _tokens(String simplified) =>
    simplified.split(RegExp('[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();

/// Le pseudo contient-il un gros mot ?
bool containsProfanity(String pseudo) {
  final simple = simplifyForModeration(pseudo);
  // Collé : séparateurs retirés, puis lettres répétées de nouveau réduites (« co.nnard »).
  final compact = simplifyForModeration(simple.replaceAll(RegExp('[^a-z0-9]'), ''));
  for (final w in _anywhere) {
    if (compact.contains(simplifyForModeration(w))) return true;
  }
  final tokens = _tokens(simple).toSet();
  for (final w in _wholeWord) {
    final sw = simplifyForModeration(w);
    if (tokens.contains(sw) || compact == sw) return true;
  }
  return false;
}
