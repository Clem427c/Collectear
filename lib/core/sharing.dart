import 'cards.dart';
import 'variants.dart';

/// « Partager ses plus belles trouvailles » (GDD diapo 12) : choix des plus belles cartes de la
/// collection et texte qui accompagne l'image d'une carte envoyée à ses amis.

/// Adresse du jeu, ajoutée au message partagé.
const shareGameUrl = 'https://clem427c.github.io/Collectear/';

/// Score d'un exemplaire pour le classer parmi les « plus belles trouvailles » :
/// d'abord la rareté de l'espèce, puis la rareté de l'apparence (étoiles), puis les stats.
// PROVISOIRE : la rareté de l'espèce compte plus que l'apparence (une Légendaire unie passe devant
// une Commune Dorée Shiny). À valider par Clem (ROADMAP, Questions).
double findScore(CardInstance inst) =>
    inst.card.rarity.index * 100 + inst.variant.stars * 10 + inst.variant.quality;

/// Les [count] plus belles trouvailles de la collection, au plus un exemplaire (le plus beau) par
/// espèce, de la plus belle à la moins belle. À égalité, le plus petit numéro passe devant.
/// [variants] : id de carte → seeds des exemplaires possédés.
List<CardInstance> bestFinds(CardPool pool, Map<int, List<int>> variants, {int count = 3}) {
  final best = <CardInstance>[];
  for (final e in variants.entries) {
    final card = pool.byId(e.key);
    if (card == null || e.value.isEmpty) continue;
    CardInstance? top;
    for (final seed in e.value) {
      final inst = CardInstance(card, seed);
      if (top == null || findScore(inst) > findScore(top)) top = inst;
    }
    best.add(top!);
  }
  best.sort((a, b) {
    final s = findScore(b).compareTo(findScore(a));
    return s != 0 ? s : a.card.id.compareTo(b.card.id);
  });
  return best.take(count).toList();
}

/// Étoiles en texte (« ★★★☆☆ »).
String starsText(int stars) => '${'★' * stars}${'☆' * (5 - stars)}';

/// Description courte de l'apparence (« Dorée Shiny », « motif Étoiles », « Uni »).
String appearanceText(Variant v) {
  final parts = <String>[
    if (v.finish != VariantFinish.normal) v.finish.label,
    if (v.shiny) 'Shiny',
  ];
  if (parts.isNotEmpty) return parts.join(' ');
  return v.pattern == VariantPattern.none ? 'Uni' : 'motif ${v.pattern.label}';
}

/// Message qui accompagne l'image partagée.
/// Ex. « Regarde ma trouvaille dans Collectear : Abyssiel (Légendaire, Dorée Shiny ★★★★★, stats +3 %) !
/// N° 291 · #4F2A. Viens jouer : https://… »
String shareMessage(CardInstance inst) {
  final v = inst.variant;
  final pct = v.statsPercent;
  final stats = pct == 0 ? 'stats moyennes' : 'stats ${pct > 0 ? '+' : '−'}${pct.abs()} %';
  return 'Regarde ma trouvaille dans Collectear : ${inst.card.name} '
      '(${inst.card.rarity.label}, ${appearanceText(v)} ${starsText(v.stars)}, $stats) ! '
      'N° ${inst.card.id.toString().padLeft(3, '0')} · ${v.code}. '
      'Viens jouer : $shareGameUrl';
}

/// Nom du fichier image partagé (« collectear_291_4F2A.png »), sans caractère spécial.
String shareFileName(CardInstance inst) =>
    'collectear_${inst.card.id.toString().padLeft(3, '0')}_${inst.variant.code.substring(1)}.png';
