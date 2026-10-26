import 'dart:io';
import 'dart:math';

import 'package:collectear/core/cards.dart';
import 'package:collectear/core/config.dart';
import 'package:collectear/core/noise.dart';
import 'package:collectear/core/run_state.dart';
import 'package:collectear/core/terrain.dart';
import 'package:flutter_test/flutter_test.dart';

CardPool _pool() => CardPool.fromJsonString(File('assets/data/cards.json').readAsStringSync());

void main() {
  group('Cartes', () {
    test('300 cartes, ids uniques, 5 raretés', () {
      final pool = _pool();
      expect(pool.cards.length, 300);
      expect(pool.cards.map((c) => c.id).toSet().length, 300);
      expect(pool.cards.map((c) => c.name).toSet().length, 300);
      for (final r in Rarity.values) {
        expect(pool.cards.where((c) => c.rarity == r), isNotEmpty);
      }
    });

    test('la puissance augmente strictement avec la rareté', () {
      final pool = _pool();
      double power(GameCard c) => c.hp / 5 + c.atk + c.def;
      for (var i = 1; i < Rarity.values.length; i++) {
        final lower = pool.cards.where((c) => c.rarity.index == i - 1).map(power).reduce(max);
        final upper = pool.cards.where((c) => c.rarity.index == i).map(power).reduce(min);
        expect(upper, greaterThan(lower), reason: 'rareté $i');
      }
    });

    test('le tirage respecte à peu près les taux', () {
      final pool = _pool();
      final rng = Random(1);
      final counts = List.filled(5, 0);
      for (var i = 0; i < 20000; i++) {
        counts[pool.drawRarity(rng).index]++;
      }
      expect(counts[0] / 20000, closeTo(0.60, 0.02));
      expect(counts[4] / 20000, closeTo(0.01, 0.005));
    });

    test('la chance réduit les communes', () {
      final pool = _pool();
      final rng = Random(2);
      var common = 0;
      for (var i = 0; i < 20000; i++) {
        if (pool.drawRarity(rng, luck: 1) == Rarity.commune) common++;
      }
      expect(common / 20000, lessThan(0.40));
    });
  });

  group('Run', () {
    test('se termine au bout du chrono', () {
      final run = RunState(const RunRules());
      run.tick(119);
      expect(run.isOver, isFalse);
      run.tick(2);
      expect(run.endReason, RunEndReason.timeUp);
    });

    test('boost temps : 2 min 30', () {
      final run = RunState(const RunRules(boost: Boost.time));
      run.tick(140);
      expect(run.isOver, isFalse);
      run.tick(11);
      expect(run.endReason, RunEndReason.timeUp);
    });

    test('mort au 2e coup, au 3e avec résistance', () {
      final a = RunState(const RunRules());
      expect(a.playerHit(), isFalse);
      expect(a.playerHit(), isTrue);
      expect(a.endReason, RunEndReason.death);

      final b = RunState(const RunRules(boost: Boost.resistance));
      b.playerHit();
      b.playerHit();
      expect(b.isOver, isFalse);
      expect(b.playerHit(), isTrue);
    });

    test('une carte tous les 10 kills, fin à 3 cartes', () {
      final pool = _pool();
      final run = RunState(const RunRules());
      var earned = 0;
      for (var i = 0; i < 9; i++) {
        if (run.registerKill()) earned++;
      }
      expect(earned, 0);
      expect(run.registerKill(), isTrue);
      run.addCard(pool.cards[0]);
      run.addCard(pool.cards[1]);
      expect(run.isOver, isFalse);
      run.addCard(pool.cards[2]);
      expect(run.endReason, RunEndReason.cardsCollected);
    });

    test('boost dégâts : ennemis en 2 coups', () {
      expect(const RunRules().enemyHitsToKill, GameConfig.enemyHitsToKill);
      expect(const RunRules(boost: Boost.damage).enemyHitsToKill, 2);
    });
  });

  group('Monde', () {
    test('le bruit est déterministe et borné', () {
      for (var i = 0; i < 1000; i++) {
        final v = fbm(42, i * 0.37, i * -0.21);
        expect(v, inInclusiveRange(0, 1));
        expect(fbm(42, i * 0.37, i * -0.21), v);
      }
      expect(hash3(1, 2, 3), hash3(1, 2, 3));
      expect(hash3(1, 2, 3), isNot(hash3(1, 3, 2)));
    });

    test('même seed = même terrain, seeds différentes = terrains différents', () {
      final a = Terrain(7), b = Terrain(7), c = Terrain(8);
      var diff = 0;
      for (var x = -40; x < 40; x++) {
        for (var y = -40; y < 40; y++) {
          expect(a.levelAt(x, y), b.levelAt(x, y));
          if (a.levelAt(x, y) != c.levelAt(x, y)) diff++;
        }
      }
      expect(diff, greaterThan(100));
    });

    test('départ dégagé et plusieurs niveaux présents', () {
      final t = Terrain(123);
      expect(t.levelAt(0, 0), 0);
      expect(t.levelAt(2, -2), 0);
      final levels = <int>{};
      for (var x = -60; x < 60; x++) {
        for (var y = -60; y < 60; y++) {
          final l = t.levelAt(x, y);
          expect(l, inInclusiveRange(0, GameConfig.maxLevel));
          levels.add(l);
        }
      }
      expect(levels.length, greaterThanOrEqualTo(3));
    });

    test('règles de hauteur : saut = +1 niveau max', () {
      expect(HeightRules.playerCanEnter(current: 1, target: 0, airborne: false), isTrue);
      expect(HeightRules.playerCanEnter(current: 1, target: 2, airborne: false), isFalse);
      expect(HeightRules.playerCanEnter(current: 1, target: 2, airborne: true), isTrue);
      expect(HeightRules.playerCanEnter(current: 1, target: 3, airborne: true), isFalse);
      expect(HeightRules.enemyCanEnter(current: 2, target: 1), isFalse);
    });
  });
}
