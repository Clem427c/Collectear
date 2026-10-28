import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collectear/core/cards.dart';
import 'package:collectear/core/cloud_sync.dart';
import 'package:collectear/core/collection.dart';
import 'package:collectear/core/config.dart';
import 'package:collectear/core/decor.dart';
import 'package:collectear/core/economy.dart';
import 'package:collectear/core/noise.dart';
import 'package:collectear/core/online_config.dart';
import 'package:collectear/core/places.dart';
import 'package:collectear/core/run_state.dart';
import 'package:collectear/core/settings.dart';
import 'package:collectear/core/terrain.dart';
import 'package:collectear/core/variants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(HeightRules.playerCanHit(attacker: 2, target: 2), isTrue);
      expect(HeightRules.playerCanHit(attacker: 2, target: 3), isTrue);
      expect(HeightRules.playerCanHit(attacker: 2, target: 1), isTrue);
      expect(HeightRules.playerCanHit(attacker: 2, target: 0), isFalse);
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
                expect(p.runeGuards.length, greaterThanOrEqualTo(PlaceRules.runesPerRuin));
                expect(p.runeGuards.length, lessThanOrEqualTo(PlaceRules.runesPerRuin * PlaceRules.guardsPerRune));
                expect(p.runeGuards.toSet().length, p.runeGuards.length);
                expect(p.runeGuards.any(p.runes.contains), isFalse);
              case PlaceType.tower:
                expect(p.level, GameConfig.maxLevel);
              case PlaceType.rareChest:
                expect(cx * cx + cy * cy, greaterThanOrEqualTo(25));
              case PlaceType.chest:
                expect(cx * cx + cy * cy, greaterThanOrEqualTo(9));
            }
            expect(p.level, t.levelAt(p.tile.x, p.tile.y));
          }
        }
      }
      expect(seen, PlaceType.values.toSet());
    });

    test('fréquences : coffres simples rares, lieux à défi plus fréquents', () {
      final t = Terrain(77);
      final counts = <PlaceType, int>{};
      var chunks = 0;
      for (var cx = -30; cx <= 30; cx++) {
        for (var cy = -30; cy <= 30; cy++) {
          chunks++;
          for (final p in PlaceRules.forChunk(t, cx, cy)) {
            counts[p.type] = (counts[p.type] ?? 0) + 1;
          }
        }
      }
      double ratio(PlaceType type) => (counts[type] ?? 0) / chunks;
      expect(ratio(PlaceType.sanctuary), closeTo(0.094, 0.025));
      expect(ratio(PlaceType.ruin), closeTo(0.094, 0.025));
      expect(ratio(PlaceType.chest) + ratio(PlaceType.rareChest), lessThan(0.08));
      expect(ratio(PlaceType.tower), closeTo(0.06, 0.02));
    });

    test('gardiens de sanctuaire : 4, tout près de l\'autel, au même étage', () {
      final t = Terrain(2026);
      var sanctuaries = 0;
      var sameLevel = 0;
      var guardians = 0;
      for (var cx = -25; cx <= 25; cx++) {
        for (var cy = -25; cy <= 25; cy++) {
          for (final p in PlaceRules.forChunk(t, cx, cy)) {
            if (p.type != PlaceType.sanctuary) continue;
            sanctuaries++;
            expect(p.guardians.length, PlaceRules.guardiansPerSanctuary);
            expect(p.guardians.toSet().length, p.guardians.length);
            for (final g in p.guardians) {
              guardians++;
              expect(max((g.x - p.tile.x).abs(), (g.y - p.tile.y).abs()), lessThanOrEqualTo(3));
              expect(g, isNot(p.tile));
              if (t.levelAt(g.x, g.y) == p.level) sameLevel++;
            }
          }
        }
      }
      expect(sanctuaries, greaterThan(50));
      expect(sameLevel / guardians, greaterThan(0.9));
    });

    test('décors : déterministes, sur des cases libres, rien autour du départ', () {
      final t = Terrain(99);
      for (final (cx, cy) in const [(0, 0), (-1, 0), (0, -1), (-1, -1)]) {
        for (final p in DecorRules.propsForChunk(t, 99, cx, cy)) {
          expect(p.tx.abs() > DecorRules.clearRadius || p.ty.abs() > DecorRules.clearRadius, isTrue);
        }
      }
      for (var cx = -6; cx <= 6; cx++) {
        for (var cy = -6; cy <= 6; cy++) {
          final props = DecorRules.propsForChunk(t, 99, cx, cy);
          final again = DecorRules.propsForChunk(t, 99, cx, cy);
          expect(props.map((p) => '${p.tx},${p.ty},${p.name}'), again.map((p) => '${p.tx},${p.ty},${p.name}'));
          expect(props.length, lessThanOrEqualTo(DecorRules.maxPerChunk));
          final reserved = DecorRules.reservedTiles(t, 99, cx, cy);
          for (final p in props) {
            expect(reserved.contains((p.tx, p.ty)), isFalse);
            expect(t.towerRing(p.tx, p.ty), isNull);
            expect(DecorRules.byLevel[t.levelAt(p.tx, p.ty)]!.any((o) => o.$1 == p.name), isTrue);
          }
        }
      }
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
  group('Synchro en ligne', () {
    test('union : envoie ce qui manque en ligne, ajoute ce qui manque en local', () {
      final plan = planSync({
        5: [10, 11],
        7: [3],
      }, const [(5, 10), (9, 42), (7, 4)]);
      expect(plan.toUpload, [(5, 11), (7, 3)]);
      expect(plan.toAddLocally, [(7, 4), (9, 42)]);
      expect(plan.isEmpty, isFalse);
    });

    test('collections identiques : rien à faire, doublons exacts ignorés', () {
      final plan = planSync({
        1: [1, 1, 2],
      }, const [(1, 2), (1, 1), (1, 1)]);
      expect(plan.isEmpty, isTrue);
    });

    test('première connexion : tout part en ligne ; nouvel appareil : tout revient', () {
      expect(planSync({3: [9]}, const []).toUpload, [(3, 9)]);
      expect(planSync({}, const [(3, 9)]).toAddLocally, [(3, 9)]);
    });

    test('lignes serveur : conversion aller-retour, lignes invalides ignorées', () {
      final rows = toRows('u1', const [(5, 10)]);
      expect(rows, [
        {'user_id': 'u1', 'card_id': 5, 'seed': 10},
      ]);
      expect(fromRows([...rows, {'card_id': 'x', 'seed': 1}, {'card_id': 2}]), [(5, 10)]);
    });

    test('envoi par lots', () {
      expect(chunked([1, 2, 3, 4, 5], 2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
      expect(chunked(<int>[], 500), isEmpty);
    });

    test('e-mail et code', () {
      expect(isPlausibleEmail('clem@exemple.fr'), isTrue);
      expect(isPlausibleEmail(' clem@exemple.fr '), isTrue);
      expect(isPlausibleEmail('clem@exemple'), isFalse);
      expect(isPlausibleEmail('clem exemple.fr'), isFalse);
      expect(isPlausibleOtp('123456'), isTrue);
      expect(isPlausibleOtp('123 456'), isTrue);
      expect(isPlausibleOtp('12345'), isFalse);
      expect(isPlausibleOtp('12a456'), isFalse);
    });

    test('messages d\'erreur de connexion', () {
      expect(authErrorMessage('email rate limit exceeded', code: 'over_email_send_rate_limit'), contains('heure'));
      expect(authErrorMessage('Email rate limit exceeded'), contains('heure'));
      expect(authErrorMessage('For security purposes, you can only request this after 42 seconds.'), contains('42 s'));
      expect(authErrorMessage('Request rate limit reached', code: 'over_request_rate_limit'), contains('minutes'));
      expect(authErrorMessage('Token has expired or is invalid', code: 'otp_expired'), contains('expiré'));
      expect(authErrorMessage('Autre chose'), 'Autre chose');
    });
  });

  group('Profil en ligne', () {
    test('pseudo : nettoyage et validation', () {
      expect(normalizePseudo('  Clem   le   Grand '), 'Clem le Grand');
      expect(pseudoError('Clem'), isNull);
      expect(pseudoError('Élodie-Marie'), isNull);
      expect(pseudoError("L'Explorateur_2"), isNull);
      expect(pseudoError('   '), isNotNull);
      expect(pseudoError('A'), isNotNull);
      expect(pseudoError('A' * 24), isNull);
      expect(pseudoError('A' * 25), isNotNull);
      expect(pseudoError('Clem<script>'), isNotNull);
      expect(pseudoError('Clem 😀'), isNotNull);
    });

    test('pseudo : le pseudo choisi l\'emporte sur celui par défaut', () {
      expect(reconcilePseudo(local: defaultPseudo, remote: 'Clem'), ('Clem', false));
      expect(reconcilePseudo(local: 'Clem', remote: defaultPseudo), ('Clem', true));
      expect(reconcilePseudo(local: 'Clem', remote: null), ('Clem', true));
      expect(reconcilePseudo(local: 'Clem', remote: 'Clémence'), ('Clémence', false));
      expect(reconcilePseudo(local: defaultPseudo, remote: null), (defaultPseudo, false));
    });

    test('statistiques : lecture du serveur et fusion avec l\'appareil', () {
      final online = ProfileStats.fromRpc([
        {'runs': 4, 'kills': '30', 'cards': 5, 'best_kills': 12},
      ])!;
      expect(online.kills, 30);
      expect(ProfileStats.fromRpc([]), isNull);
      expect(ProfileStats.fromRpc('x'), isNull);
      final merged = const ProfileStats(runs: 10, kills: 20, cards: 6, bestKills: 9).merge(online);
      expect([merged.runs, merged.kills, merged.cards, merged.bestKills], [10, 30, 6, 12]);
      expect(const ProfileStats(runs: 1).merge(null).runs, 1);
    });

    test('cartes d\'une run pour finish_run', () {
      expect(runCardsPayload(const [(12, 345), (300, 0)]), [
        {'card_id': 12, 'seed': 345},
        {'card_id': 300, 'seed': 0},
      ]);
    });
  });

  group('Serveur', () {
    // Les limites de la base (supabase/schema.sql) doivent suivre celles du jeu.
    final sql = File('supabase/schema.sql').readAsStringSync();
    int sqlConst(String name) =>
        int.parse(RegExp('$name constant int := (\\d+);').firstMatch(sql)!.group(1)!);

    test('limites de schema.sql identiques à config.dart et economy.dart', () {
      expect(sqlConst('runs_per_day'), GameConfig.runsPerDay);
      expect(sqlConst('max_energies_per_day'), Economy.maxEnergyPurchasesPerDay);
      expect(sqlConst('max_cards'), GameConfig.maxCardsPerRun);
      expect(sql, contains('check (cards between 0 and ${GameConfig.maxCardsPerRun})'));
      expect(sql, contains("display_name text not null default '$defaultPseudo'"));
      expect(sql, contains('char_length(display_name) between 1 and $maxPseudoLength'));
    });

    test('RLS activé sur toutes les tables', () {
      final tables = RegExp(r'create table if not exists public\.(\w+)').allMatches(sql).map((m) => m.group(1)!).toList();
      expect(tables, containsAll(['profiles', 'owned_cards', 'runs']));
      for (final t in tables) {
        expect(sql, contains('alter table public.$t enable row level security'), reason: t);
      }
    });
  });

  group('Pièces et énergies', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test('prix croissant, 5 énergies par jour au plus', () {
      expect([for (var i = 0; i < 5; i++) Economy.energyPrice(i)], [60, 100, 140, 180, 220]);
      expect(Economy.energyPrice(5), isNull);
    });

    test('pièces au sol : déterministes, aucune au départ, plus fréquentes que les cartes', () {
      expect(Economy.coinsForChunk(42, 0, 0), isEmpty);
      expect(Economy.coinsForChunk(42, 3, -2), Economy.coinsForChunk(42, 3, -2));
      var total = 0;
      var chunks = 0;
      for (var cx = -15; cx <= 15; cx++) {
        for (var cy = -15; cy <= 15; cy++) {
          chunks++;
          final coins = Economy.coinsForChunk(42, cx, cy);
          for (final (tx, ty, v) in coins) {
            expect(Terrain.chunkOf(tx), cx);
            expect(Terrain.chunkOf(ty), cy);
            expect(v, anyOf(Economy.coinValue, Economy.pileValue));
            total += v;
          }
          expect(coins.map((c) => (c.$1, c.$2)).toSet().length, coins.length);
        }
      }
      // ~2 pièces par chunk en moyenne (1,5 isolées + un tas de 5 une fois sur 8).
      expect(total / chunks, closeTo(2.1, 0.4));
    });

    test('les pièces de la run ne bougent plus une fois la run finie', () {
      final run = RunState(const RunRules());
      run.addCoins(3);
      run.addCoins(-2);
      expect(run.coins, 3);
      run.quit();
      run.addCoins(5);
      expect(run.coins, 3);
    });

    test('achat d\'énergie : seulement runs épuisées, assez de pièces, 5 par jour', () async {
      SharedPreferences.setMockInitialValues({});
      final col = await Collection.load();
      expect(col.coins, 0);
      expect(col.runsLeftToday, GameConfig.runsPerDay);
      await col.addCoins(1000);
      expect(col.canBuyEnergy, isFalse, reason: 'il reste des runs gratuites');
      for (var i = 0; i < GameConfig.runsPerDay; i++) {
        await col.registerRun();
      }
      expect(col.runsLeftToday, 0);
      var spent = 0;
      for (var i = 0; i < Economy.maxEnergyPurchasesPerDay; i++) {
        spent += col.nextEnergyPrice!;
        expect(await col.buyEnergy(), isTrue);
        expect(col.runsLeftToday, 1);
        expect(await col.buyEnergy(), isFalse, reason: 'une seule énergie d\'avance');
        await col.registerRun();
      }
      expect(col.coins, 1000 - spent);
      expect(col.energyBoughtToday, Economy.maxEnergyPurchasesPerDay);
      expect(col.nextEnergyPrice, isNull);
      expect(await col.buyEnergy(), isFalse);
      expect(col.runsLeftToday, 0);
    });

    test('pas assez de pièces : pas d\'achat', () async {
      SharedPreferences.setMockInitialValues({});
      final col = await Collection.load();
      for (var i = 0; i < GameConfig.runsPerDay; i++) {
        await col.registerRun();
      }
      await col.addCoins(59);
      expect(await col.buyEnergy(), isFalse);
      expect(col.coins, 59);
    });
  });

  group('Réglages', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test('valeurs par défaut, enregistrement, volume borné', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await Settings.load();
      expect(s.volume, 0.8);
      expect(s.haptics, isTrue);
      expect(s.loginPromptShown, isFalse);
      await s.setVolume(1.7);
      await s.setHaptics(false);
      await s.markLoginPromptShown();
      final again = await Settings.load();
      expect(again.volume, 1.0);
      expect(again.haptics, isFalse);
      expect(again.loginPromptShown, isTrue);
    });
  });
}
