import 'dart:io';

import 'package:collectear/core/cards.dart';
import 'package:collectear/core/sharing.dart';
import 'package:collectear/core/variants.dart';
import 'package:flutter_test/flutter_test.dart';

CardPool _pool() => CardPool.fromJsonString(File('assets/data/cards.json').readAsStringSync());

/// Première seed (≥ [from]) dont l'apparence vérifie [test].
int _seed(bool Function(Variant v) test, {int from = 0}) {
  for (var s = from;; s++) {
    if (test(Variant.fromSeed(s))) return s;
  }
}

void main() {
  final pool = _pool();
  GameCard ofRarity(Rarity r, [int skip = 0]) => pool.cards.where((c) => c.rarity == r).elementAt(skip);

  final plain = _seed((v) => v.stars == 1);
  final shiny = _seed((v) => v.stars == 3);
  final golden = _seed((v) => v.finish == VariantFinish.golden && v.stars == 4);

  group('Plus belles trouvailles', () {
    test('collection vide : aucune trouvaille', () {
      expect(bestFinds(pool, {}), isEmpty);
      expect(bestFinds(pool, {1: []}), isEmpty);
    });

    test('la rareté de l\'espèce passe avant l\'apparence', () {
      final leg = ofRarity(Rarity.legendaire);
      final com = ofRarity(Rarity.commune);
      final finds = bestFinds(pool, {com.id: [golden], leg.id: [plain]});
      expect(finds.map((i) => i.card.id), [leg.id, com.id]);
    });

    test('à rareté égale, les étoiles départagent', () {
      final a = ofRarity(Rarity.rare, 0);
      final b = ofRarity(Rarity.rare, 1);
      final finds = bestFinds(pool, {a.id: [plain], b.id: [shiny]});
      expect(finds.first.card.id, b.id);
    });

    test('un seul exemplaire par espèce : le plus beau', () {
      final c = ofRarity(Rarity.epique);
      final finds = bestFinds(pool, {c.id: [plain, golden, shiny]});
      expect(finds, hasLength(1));
      expect(finds.single.variantSeed, golden);
    });

    test('au plus [count] trouvailles, triées', () {
      final ids = pool.cards.take(10).map((c) => c.id);
      final finds = bestFinds(pool, {for (final id in ids) id: [plain]}, count: 3);
      expect(finds, hasLength(3));
      for (var i = 1; i < finds.length; i++) {
        expect(findScore(finds[i - 1]) >= findScore(finds[i]), isTrue);
      }
    });

    test('une carte inconnue est ignorée', () {
      expect(bestFinds(pool, {99999: [plain]}), isEmpty);
    });
  });

  group('Message partagé', () {
    test('contient le nom, la rareté, l\'apparence, le numéro et le lien', () {
      final card = ofRarity(Rarity.legendaire);
      final inst = CardInstance(card, golden);
      final msg = shareMessage(inst);
      expect(msg, contains(card.name));
      expect(msg, contains('Légendaire'));
      expect(msg, contains('Dorée'));
      expect(msg, contains('★★★★☆'));
      expect(msg, contains('N° ${card.id.toString().padLeft(3, '0')}'));
      expect(msg, contains(inst.variant.code));
      expect(msg, endsWith(shareGameUrl));
    });

    test('stats : signe et « moyennes »', () {
      final card = ofRarity(Rarity.commune);
      final up = CardInstance(card, _seed((v) => v.statsPercent > 0));
      final down = CardInstance(card, _seed((v) => v.statsPercent < 0));
      final zero = CardInstance(card, _seed((v) => v.statsPercent == 0));
      expect(shareMessage(up), contains('stats +${up.variant.statsPercent} %'));
      expect(shareMessage(down), contains('stats −${-down.variant.statsPercent} %'));
      expect(shareMessage(zero), contains('stats moyennes'));
    });

    test('apparence en texte', () {
      expect(appearanceText(Variant.fromSeed(shiny)), contains('Shiny'));
      expect(appearanceText(Variant.fromSeed(_seed((v) => v.stars == 1 && v.pattern == VariantPattern.none))), 'Uni');
      expect(appearanceText(Variant.fromSeed(_seed((v) => v.stars == 1 && v.pattern == VariantPattern.stripes))),
          'motif Rayures');
      expect(starsText(2), '★★☆☆☆');
    });

    test('nom de fichier sans caractère spécial', () {
      final inst = CardInstance(pool.cards.first, golden);
      final name = shareFileName(inst);
      expect(name, matches(RegExp(r'^collectear_\d{3}_[0-9A-F]{4}\.png$')));
    });
  });
}
