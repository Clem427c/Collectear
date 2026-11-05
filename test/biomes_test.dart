import 'dart:math';

import 'package:collectear/core/biomes.dart';
import 'package:collectear/core/config.dart';
import 'package:collectear/core/decor.dart';
import 'package:collectear/core/terrain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Biomes (PROVISOIRE)', () {
    test('seuils du bruit : rocailles, prairie, forêt', () {
      expect(BiomeMap.fromNoise(0.1), Biome.rocailles);
      expect(BiomeMap.fromNoise(BiomeMap.rockBelow), Biome.prairie);
      expect(BiomeMap.fromNoise(0.5), Biome.prairie);
      expect(BiomeMap.fromNoise(0.9), Biome.foret);
    });

    test('déterministes et tous présents dans des proportions raisonnables', () {
      final counts = {for (final b in Biome.values) b: 0};
      var total = 0;
      for (final seed in const [1, 99, 4242, 7, 123456]) {
        final a = BiomeMap(seed), b = BiomeMap(seed);
        for (var x = -150; x < 150; x += 5) {
          for (var y = -150; y < 150; y += 5) {
            final biome = a.at(x, y);
            expect(b.at(x, y), biome);
            counts[biome] = counts[biome]! + 1;
            total++;
          }
        }
      }
      for (final b in Biome.values) {
        expect(counts[b]! / total, inInclusiveRange(0.2, 0.5), reason: b.label);
      }
    });

    test('zones assez grandes : deux cases voisines ont presque toujours le même biome', () {
      final m = BiomeMap(99);
      var same = 0, n = 0;
      for (var x = -100; x < 100; x += 3) {
        for (var y = -100; y < 100; y += 3) {
          if (m.at(x, y) == m.at(x + 1, y)) same++;
          n++;
        }
      }
      expect(same / n, greaterThan(0.95));
    });

    test('un monde de 2 minutes traverse plusieurs biomes', () {
      // Une run à fond en ligne droite ≈ 450 cases : on doit croiser au moins 2 biomes, quelle que soit la direction.
      for (final seed in const [1, 99, 4242]) {
        final m = BiomeMap(seed);
        for (final (dx, dy) in const [(1, 0), (0, 1), (-1, 0), (0, -1)]) {
          final seen = {for (var i = 0; i < 450; i += 4) m.at(dx * i, dy * i)};
          expect(seen.length, greaterThanOrEqualTo(2));
        }
      }
    });

    test('densité d\'ennemis : prairie plus calme, forêt plus peuplée', () {
      final rng = Random(3);
      for (var base = 0; base <= 4; base++) {
        var prairie = 0, foret = 0, rocailles = 0;
        for (var i = 0; i < 4000; i++) {
          final p = BiomeRules.enemyCount(base, Biome.prairie, rng.nextDouble());
          final f = BiomeRules.enemyCount(base, Biome.foret, rng.nextDouble());
          final r = BiomeRules.enemyCount(base, Biome.rocailles, rng.nextDouble());
          expect(p, inInclusiveRange(max(0, base - 1), base));
          expect(f, inInclusiveRange(base, base + 1 + base ~/ 4));
          expect(r, base);
          prairie += p;
          foret += f;
          rocailles += r;
        }
        expect(prairie / 4000, closeTo(base * Biome.prairie.enemyDensity, 0.06));
        expect(foret / 4000, closeTo(base * Biome.foret.enemyDensity, 0.06));
        expect(rocailles / 4000, base.toDouble());
      }
      expect(BiomeRules.enemyCount(0, Biome.foret, 0), 0); // jamais d'ennemi sorti de rien
    });

    test('tireurs surtout dans les rocailles, corps à corps surtout en forêt', () {
      expect(Biome.rocailles.meleeShare, lessThan(0.5));
      expect(Biome.foret.meleeShare, greaterThan(Biome.prairie.meleeShare));
    });

    test('décors : plus d\'arbres en forêt, plus de rochers dans les rocailles, jamais un décor d\'un autre étage', () {
      const trees = {'prop_arbre_rond', 'prop_arbre_pin', 'prop_arbre_fruits', 'prop_arbre_enneige'};
      const rocks = {'prop_rocher', 'prop_rochers_petits', 'prop_cristaux'};
      final stats = {for (final b in Biome.values) b: [0, 0, 0]}; // arbres, rochers, total
      for (final seed in const [1, 99, 4242]) {
        final t = Terrain(seed);
        final m = BiomeMap(seed);
        for (var cx = -10; cx <= 10; cx++) {
          for (var cy = -10; cy <= 10; cy++) {
            final props = DecorRules.propsForChunk(t, seed, cx, cy);
            expect(props.length, lessThanOrEqualTo(DecorRules.maxPerChunkWithBiome));
            for (final p in props) {
              expect(DecorRules.byLevel[t.levelAt(p.tx, p.ty)]!.any((o) => o.$1 == p.name), isTrue);
              final s = stats[m.at(p.tx, p.ty)]!;
              if (trees.contains(p.name)) s[0]++;
              if (rocks.contains(p.name)) s[1]++;
              s[2]++;
            }
          }
        }
      }
      double share(Biome b, int i) => stats[b]![i] / stats[b]![2];
      expect(share(Biome.foret, 0), greaterThan(share(Biome.prairie, 0)));
      expect(share(Biome.foret, 0), greaterThan(share(Biome.rocailles, 0)));
      expect(share(Biome.rocailles, 1), greaterThan(share(Biome.prairie, 1)));
      expect(share(Biome.rocailles, 1), greaterThan(share(Biome.foret, 1)));
    });

    test('biome d\'un chunk = celui de sa case centrale', () {
      final m = BiomeMap(42);
      const n = GameConfig.chunkTiles;
      expect(m.ofChunk(3, -2), m.at(3 * n + n ~/ 2, -2 * n + n ~/ 2));
    });
  });

  group('Annonce du biome en run', () {
    test('le biome de départ n\'est pas annoncé, le suivant l\'est après un court délai', () {
      final t = BiomeTracker();
      expect(t.update(Biome.prairie, 0.016), isNull);
      expect(t.current, Biome.prairie);
      expect(t.update(Biome.foret, 0.5), isNull); // pas encore installé
      expect(t.update(Biome.foret, 0.8), Biome.foret);
      expect(t.current, Biome.foret);
      expect(t.visited, [Biome.prairie, Biome.foret]);
    });

    test('pas de clignotement à la frontière', () {
      final t = BiomeTracker()..update(Biome.prairie, 0.016);
      for (var i = 0; i < 50; i++) {
        expect(t.update(i.isEven ? Biome.foret : Biome.prairie, 0.5), isNull);
      }
      expect(t.current, Biome.prairie);
    });

    test('deux annonces espacées d\'au moins 8 s ; attend qu\'aucun autre message ne soit affiché', () {
      final t = BiomeTracker()..update(Biome.prairie, 0.016);
      expect(t.update(Biome.foret, 2), Biome.foret);
      expect(t.update(Biome.rocailles, 2), isNull); // trop tôt après la précédente
      expect(t.update(Biome.rocailles, 3), isNull);
      expect(t.update(Biome.rocailles, 3.5, canAnnounce: false), isNull); // un autre message est affiché
      expect(t.update(Biome.rocailles, 0.1), Biome.rocailles);
      expect(t.visited, [Biome.prairie, Biome.foret, Biome.rocailles]);
    });
  });
}
