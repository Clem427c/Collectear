import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collectear/core/cards.dart';
import 'package:collectear/core/companion.dart';
import 'package:collectear/core/collection.dart';
import 'package:collectear/core/config.dart';
import 'package:collectear/core/cosmetics.dart';
import 'package:collectear/core/variants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Accessoires du compagnon (PROVISOIRE)', () {
    test('catalogue : identifiants uniques, « aucun » offert et en premier, prix positifs', () {
      expect(Accessories.all.map((a) => a.id).toSet().length, Accessories.all.length);
      expect(Accessories.all.where((a) => a.isDefault).length, 1);
      expect(Accessories.all.first.id, Accessories.defaultId);
      expect(Accessories.all.first.style, AccessoryStyle.none);
      expect(Accessories.byId('inconnu').id, Accessories.defaultId);
      for (final a in Accessories.all.skip(1)) {
        expect(a.price, greaterThan(0), reason: a.id);
        expect(a.style, isNot(AccessoryStyle.none), reason: a.id);
        expect(a.color >> 24, 0xFF, reason: a.id);
      }
      expect(Accessories.byId('aureole').floats, isTrue);
      expect(Accessories.byId('chapeau').floats, isFalse);
    });

    test('achat avec les pièces, porté aussitôt, puis « aucun »', () async {
      SharedPreferences.setMockInitialValues({});
      final col = await Collection.load();
      final crown = Accessories.byId('couronne');
      expect(col.equippedAccessory.id, Accessories.defaultId);
      expect(await col.buyAccessory(crown), isFalse); // pas assez de pièces
      expect(Accessories.whyNotBuy(crown, owned: col.ownedAccessories, coins: col.coins), contains('manque'));
      await col.addCoins(crown.price + 7);
      expect(await col.buyAccessory(crown), isTrue);
      expect(col.coins, 7);
      expect(col.ownedAccessories, {Accessories.defaultId, 'couronne'});
      expect(col.equippedAccessory.id, 'couronne');
      expect(await col.buyAccessory(crown), isFalse); // déjà possédé : pas débité deux fois
      expect(col.coins, 7);
      expect(await col.equipAccessory(Accessories.byId('lucioles')), isFalse); // pas possédé
      expect(await col.equipAccessory(Accessories.byId(Accessories.defaultId)), isTrue);
      expect(col.equippedAccessory.isDefault, isTrue);
      // Skins et cadres ne sont pas touchés.
      expect(col.ownedSkins, {Skins.defaultId});
      expect(col.ownedFrames, {CardFrames.defaultId});
    });

    test('accessoire enregistré mais pas possédé : aucun', () async {
      SharedPreferences.setMockInitialValues({'equipped_accessory': 'couronne'});
      final col = await Collection.load();
      expect(col.equippedAccessory.id, Accessories.defaultId);
    });

    Uint8List blank(int w, int h) => Uint8List(w * h * 4);
    void dot(Uint8List px, int w, int x, int y) => px[(y * w + x) * 4 + 3] = 255;

    test('haut du dessin : première ligne dessinée et milieu de la tête', () {
      const w = 100, h = 100;
      final px = blank(w, h);
      // Une « tête » (disque) centrée en x = 60, dont le haut est à y = 20, sur un corps plus large.
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final head = (x - 60) * (x - 60) + (y - 32) * (y - 32) <= 12 * 12;
          final body = y >= 44 && y < 90 && x >= 30 && x < 90;
          if (head || body) dot(px, w, x, y);
        }
      }
      final a = findHeadAnchor(px, w, h);
      expect(a.top, closeTo(0.20, 0.02));
      expect(a.x, closeTo(0.60, 0.02));
    });

    test('poussière isolée ignorée, image vide ou mal formée : repli', () {
      const w = 200, h = 200;
      final px = blank(w, h);
      dot(px, w, 5, 3); // un pixel perdu en haut à gauche
      for (var y = 80; y < 150; y++) {
        for (var x = 90; x < 110; x++) {
          dot(px, w, x, y);
        }
      }
      final a = findHeadAnchor(px, w, h);
      expect(a.top, closeTo(0.40, 0.01));
      expect(a.x, closeTo(0.5, 0.01));
      expect(findHeadAnchor(blank(w, h), w, h), same(HeadAnchor.fallback));
      expect(findHeadAnchor(Uint8List(10), w, h), same(HeadAnchor.fallback));
      expect(findHeadAnchor(px, 0, 0), same(HeadAnchor.fallback));
    });
  });
}
