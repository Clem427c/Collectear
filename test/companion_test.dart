import 'dart:io';
import 'dart:math' as math;

import 'package:collectear/core/cards.dart';
import 'package:collectear/core/companion.dart';
import 'package:collectear/core/config.dart';
import 'package:collectear/core/variants.dart';
import 'package:flutter_test/flutter_test.dart';

CardPool _pool() => CardPool.fromJsonString(File('assets/data/cards.json').readAsStringSync());

double _dist(CompanionFollower c, double x, double y) => math.sqrt((c.x - x) * (c.x - x) + (c.y - y) * (c.y - y));

void main() {
  group('Compagnon dessiné en run (PROVISOIRE)', () {
    test('plus bel exemplaire choisi (étoiles puis stats), null sans exemplaire', () {
      final card = _pool().cards.first;
      expect(companionInstance(card, null), isNull);
      expect(companionInstance(card, const []), isNull);
      final seeds = List<int>.generate(400, (i) => i * 7919 + 3);
      final best = companionInstance(card, seeds)!;
      for (final s in seeds) {
        final v = Variant.fromSeed(s);
        expect(v.stars <= best.variant.stars, isTrue);
        if (v.stars == best.variant.stars) expect(v.quality <= best.variant.quality + 1e-9, isTrue);
      }
      expect(companionInstance(card, [seeds[5]])!.variantSeed, seeds[5]);
    });

    test('taille : plus grand selon la rareté et la taille de l\'exemplaire', () {
      final pool = _pool();
      final common = pool.cards.firstWhere((c) => c.rarity == Rarity.commune);
      final legend = pool.cards.firstWhere((c) => c.rarity == Rarity.legendaire);
      const seed = 12345;
      final mult = Variant.fromSeed(seed).sizeMult;
      expect(companionHeight(CardInstance(common, seed)), closeTo(GameConfig.companionHeight * mult, 1e-9));
      expect(companionHeight(CardInstance(legend, seed)), greaterThan(companionHeight(CardInstance(common, seed))));
      // Toujours plus petit que l'explorateur (40) ou presque.
      for (final c in pool.cards) {
        expect(companionHeight(CardInstance(c, seed)), lessThan(41));
      }
    });

    test('se place derrière le joueur, du côté opposé à son regard', () {
      final c = CompanionFollower(0, 0);
      final (tx, ty) = c.target(100, 100, 1, 0); // le joueur regarde à droite
      expect(tx, lessThan(100));
      expect(ty, greaterThanOrEqualTo(100)); // décalé vers le bas, ne cache pas le joueur
      final (ux, uy) = c.target(100, 100, 0, -1); // le joueur regarde en haut
      expect(uy, greaterThan(100));
      expect(ux, isNot(100));
      // Regard nul : pas de division par zéro.
      final (zx, zy) = c.target(0, 0, 0, 0);
      expect(zx.isFinite && zy.isFinite, isTrue);
    });

    test('rejoint le joueur qui marche, sans le dépasser, et s\'arrête près de lui', () {
      final c = CompanionFollower(0, 0);
      var px = 0.0;
      const dt = 1 / 60;
      for (var i = 0; i < 60 * 5; i++) {
        px += GameConfig.playerSpeed * GameConfig.speedBoostMultiplier * dt; // boost Vitesse
        c.update(dt, px, 0, 1, 0);
        expect(c.x, lessThan(px)); // toujours derrière
      }
      expect(c.teleports, 0);
      expect(_dist(c, px, 0), lessThan(3 * GameConfig.tileSize)); // ne se laisse pas distancer
      expect(c.facingLeft, isFalse);
      // Le joueur s'arrête : le compagnon arrive et ne bouge plus.
      for (var i = 0; i < 60 * 3; i++) {
        c.update(dt, px, 0, 1, 0);
      }
      expect(c.moving, isFalse);
      final (tx, ty) = c.target(px, 0, 1, 0);
      expect(_dist(c, tx, ty), lessThanOrEqualTo(GameConfig.companionArriveDistance));
    });

    test('réapparaît à côté du joueur s\'il est distancé', () {
      final c = CompanionFollower(0, 0);
      c.update(1 / 60, 10 * GameConfig.tileSize, 0, 1, 0);
      expect(c.teleports, 1);
      expect(_dist(c, 10 * GameConfig.tileSize, 0), lessThan(2 * GameConfig.tileSize));
    });

    test('regarde vers la gauche quand il va à gauche ; saut de joie puis repos', () {
      final c = CompanionFollower(200, 0);
      c.update(0.1, 0, 0, -1, 0);
      expect(c.facingLeft, isTrue);
      c.celebrate();
      expect(c.hop(0), greaterThanOrEqualTo(0));
      c.update(GameConfig.companionCheerDuration / 2, 0, 0, -1, 0);
      expect(c.hop(0), greaterThan(5)); // en l'air au milieu du saut
      c.update(GameConfig.companionCheerDuration, 0, 0, -1, 0);
      expect(c.cheer, 0);
      expect(c.hop(1), lessThan(5));
    });
  });
}
