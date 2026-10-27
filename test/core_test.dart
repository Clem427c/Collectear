import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collectear/core/cards.dart';
import 'package:collectear/core/config.dart';
import 'package:collectear/core/noise.dart';
import 'package:collectear/core/online_config.dart';
import 'package:collectear/core/places.dart';
import 'package:collectear/core/run_state.dart';
import 'package:collectear/core/terrain.dart';
import 'package:collectear/core/variants.dart';
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

    test('chaque carte a un boost, les 4 boosts sont présents', () {
      final pool = _pool();
      expect(pool.cards.map((c) => c.boost).toSet().length, Boost.values.length);
      final speedy = pool.cards.where((c) => c.name.startsWith('Hériss'));
      expect(speedy.every((c) => c.boost != Boost.speed), isTrue);
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

    test('3 vies, 4 avec le boost résistance', () {
      final a = RunState(const RunRules());
      expect(a.playerHit(), isFalse);
      expect(a.playerHit(), isFalse);
      expect(a.playerHit(), isTrue);
      expect(a.endReason, RunEndReason.death);

      final b = RunState(const RunRules(boost: Boost.resistance));
      for (var i = 0; i < 3; i++) {
        b.playerHit();
      }
      expect(b.isOver, isFalse);
      expect(b.playerHit(), isTrue);
    });

    test('une vie rendue tous les 3 kills si une vie a été perdue', () {
      final run = RunState(const RunRules());
      // Aucun dégât : rien à rendre.
      for (var i = 0; i < 3; i++) {
        run.registerKill();
      }
      expect(run.hitsLeft, 3);
      expect(run.livesRegained, 0);
      run.playerHit();
      run.playerHit();
      expect(run.hitsLeft, 1);
      run.registerKill();
      run.registerKill();
      expect(run.hitsLeft, 1);
      run.registerKill(); // 6e kill
      expect(run.hitsLeft, 2);
      for (var i = 0; i < 3; i++) {
        run.registerKill();
      }
      expect(run.hitsLeft, 3);
      expect(run.livesRegained, 2);
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
      run.addCard(CardInstance(pool.cards[0], 1));
      run.addCard(CardInstance(pool.cards[1], 2));
      expect(run.isOver, isFalse);
      run.addCard(CardInstance(pool.cards[2], 3));
      expect(run.endReason, RunEndReason.cardsCollected);
    });

    test('boost portée : attaque plus longue', () {
      expect(const RunRules(boost: Boost.range).attackRange, greaterThan(const RunRules().attackRange));
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

    test('jamais coincé : deux cases voisines diffèrent d\'au plus 1 niveau', () {
      for (final seed in [1, 42, 777, 2026, 99999]) {
        final t = Terrain(seed);
        for (var x = -80; x < 80; x++) {
          for (var y = -80; y < 80; y++) {
            final l = t.levelAt(x, y);
            expect((l - t.levelAt(x + 1, y)).abs(), lessThanOrEqualTo(1));
            expect((l - t.levelAt(x, y + 1)).abs(), lessThanOrEqualTo(1));
            expect((l - t.levelAt(x + 1, y + 1)).abs(), lessThanOrEqualTo(1));
          }
        }
      }
    });

    test('règles de hauteur : saut = +1 niveau max', () {
      expect(HeightRules.playerCanEnter(current: 1, target: 0, airborne: false), isTrue);
      expect(HeightRules.playerCanEnter(current: 1, target: 2, airborne: false), isFalse);
      expect(HeightRules.playerCanEnter(current: 1, target: 2, airborne: true), isTrue);
      expect(HeightRules.playerCanEnter(current: 1, target: 3, airborne: true), isFalse);
      expect(HeightRules.enemyCanEnter(current: 2, target: 1), isFalse);
    });
  });

  group('Lieux', () {
    test('aucun lieu près du départ, génération déterministe', () {
      final t = Terrain(5);
      for (var cx = -1; cx <= 1; cx++) {
        for (var cy = -1; cy <= 1; cy++) {
          expect(PlaceRules.forChunk(t, cx, cy), isEmpty);
        }
      }
      final a = PlaceRules.forChunk(t, 4, -3).map((p) => '${p.type}${p.tile}').toList();
      final b = PlaceRules.forChunk(Terrain(5), 4, -3).map((p) => '${p.type}${p.tile}').toList();
      expect(a, b);
    });

    test('tous les types de lieux existent, avec leurs règles', () {
      final t = Terrain(2026);
      final seen = <PlaceType>{};
      for (var cx = -20; cx <= 20; cx++) {
        for (var cy = -20; cy <= 20; cy++) {
          for (final p in PlaceRules.forChunk(t, cx, cy)) {
            seen.add(p.type);
            switch (p.type) {
              case PlaceType.sanctuary:
                expect(p.guardians.length, PlaceRules.guardiansPerSanctuary);
              case PlaceType.ruin:
                expect(p.runes.toSet().length, PlaceRules.runesPerRuin);
                expect(p.runes.contains(p.tile), isFalse);
              case PlaceType.tower:
                expect(p.level, GameConfig.maxLevel);
              case PlaceType.rareChest:
                expect(cx * cx + cy * cy, greaterThanOrEqualTo(25));
              case PlaceType.chest:
                break;
            }
            expect(p.level, t.levelAt(p.tile.x, p.tile.y));
          }
        }
      }
      expect(seen, PlaceType.values.toSet());
    });

    test('une tour se gravit niveau par niveau jusqu\'au sommet', () {
      final t = Terrain(2026);
      late int cx, cy;
      search:
      for (cx = 2; cx < 60; cx++) {
        for (cy = 2; cy < 60; cy++) {
          if (t.hasTower(cx, cy)) break search;
        }
      }
      final c = t.towerCenter(cx, cy);
      for (var d = 0; d <= Terrain.towerRadius; d++) {
        expect(t.levelAt(c.x + d, c.y), GameConfig.maxLevel - d);
      }
    });
  });

  group('Variantes', () {
    test('qualité entre 0 et 1, étoiles entre 1 et 5, toutes atteintes', () {
      final stars = <int>{};
      for (var seed = 0; seed < 5000; seed++) {
        final v = Variant.fromSeed(seed);
        expect(v.quality, inInclusiveRange(0.0, 1.0));
        expect(v.stars, inInclusiveRange(1, 5));
        stars.add(v.stars);
      }
      expect(stars, {1, 2, 3, 4, 5});
    });

    test('la qualité suit la moyenne des stats', () {
      Variant? best, worst;
      for (var seed = 0; seed < 2000; seed++) {
        final v = Variant.fromSeed(seed);
        if (best == null || v.quality > best.quality) best = v;
        if (worst == null || v.quality < worst.quality) worst = v;
      }
      double avg(Variant v) => (v.hpMult + v.atkMult + v.defMult) / 3;
      expect(avg(best!), greaterThan(avg(worst!)));
      expect(best.stars, greaterThanOrEqualTo(worst.stars));
    });

    test('écart en pourcentage', () {
      expect(Variant.deltaPercent(1.031), 3);
      expect(Variant.deltaPercent(0.962), -4);
      expect(Variant.deltaPercent(1.0), 0);
      for (var seed = 0; seed < 500; seed++) {
        final v = Variant.fromSeed(seed);
        expect(Variant.deltaPercent(v.hpMult).abs(), lessThanOrEqualTo(4));
      }
    });

    test('chaque motif a un nom', () {
      expect(VariantPattern.values.map((p) => p.label).toSet().length, VariantPattern.values.length);
    });

    test('déterministes et variées', () {
      final a = Variant.fromSeed(1234), b = Variant.fromSeed(1234);
      expect(a.hue, b.hue);
      expect(a.pattern, b.pattern);
      expect(a.hpMult, b.hpMult);
      final hues = {for (var s = 0; s < 200; s++) (Variant.fromSeed(s).hue ~/ 30)};
      expect(hues.length, greaterThan(8));
    });

    test('raretés des variantes à peu près respectées', () {
      var shiny = 0, special = 0;
      const n = 20000;
      for (var s = 0; s < n; s++) {
        final v = Variant.fromSeed(s * 31 + 7);
        if (v.shiny) shiny++;
        if (v.finish != VariantFinish.normal) special++;
      }
      expect(shiny / n, closeTo(Variant.shinyChance, 0.01));
      expect(special / n, closeTo(1 / 100 + 2 / 150, 0.008));
    });

    test('les stats varient de ±4 % au plus et respectent les paliers de rareté', () {
      final pool = _pool();
      double power(CardInstance c) => c.hp / 5 + c.atk + c.def;
      final lo = <Rarity, double>{}, hi = <Rarity, double>{};
      for (final card in pool.cards) {
        for (var s = 0; s < 40; s++) {
          final inst = CardInstance(card, card.id * 1000 + s);
          expect((inst.hp - card.hp).abs(), lessThanOrEqualTo((card.hp * 0.04).ceil()));
          final p = power(inst);
          lo[card.rarity] = min(lo[card.rarity] ?? 1e9, p);
          hi[card.rarity] = max(hi[card.rarity] ?? 0, p);
        }
      }
      for (var i = 1; i < Rarity.values.length; i++) {
        expect(lo[Rarity.values[i]]!, greaterThan(hi[Rarity.values[i - 1]]!));
      }
    });
  });

  group('Configuration en ligne', () {
    String jwt(String role) {
      String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'iss': 'supabase', 'role': role})}.signature';
    }

    test('absente en local', () {
      expect(const OnlineConfig('', '').status, OnlineConfigStatus.absent);
      expect(const OnlineConfig('', '').isUsable, isFalse);
    });

    test('clé publishable et URL valides', () {
      const c = OnlineConfig(' https://abcd.supabase.co/ ', 'sb_publishable_AbCdEf123456789');
      expect(c.status, OnlineConfigStatus.ok);
      expect(c.cleanUrl, 'https://abcd.supabase.co');
    });

    test('ancienne clé anon acceptée, service_role refusée', () {
      expect(OnlineConfig.isValidKey(jwt('anon')), isTrue);
      expect(OnlineConfig.isValidKey(jwt('service_role')), isFalse);
    });

    test('clé secrète ou mal formée refusée', () {
      expect(OnlineConfig.isValidKey('sb_secret_AbCdEf123456789'), isFalse);
      expect(OnlineConfig.isValidKey('sb_publishable_'), isFalse);
      expect(OnlineConfig.isValidKey('n_importe_quoi'), isFalse);
      expect(const OnlineConfig('https://abcd.supabase.co', 'sb_secret_xxxxxxxxxxxx').status,
          OnlineConfigStatus.invalidKey);
    });

    test('URL invalide', () {
      expect(const OnlineConfig('abcd.supabase.co', 'sb_publishable_AbCdEf123456789').status,
          OnlineConfigStatus.invalidUrl);
      expect(const OnlineConfig('http://abcd.supabase.co', 'sb_publishable_AbCdEf123456789').status,
          OnlineConfigStatus.invalidUrl);
    });
  });
}
