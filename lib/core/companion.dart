import 'dart:math' as math;
import 'dart:typed_data';

import 'config.dart';
import 'sharing.dart' show findScore;
import 'variants.dart';
import 'cards.dart';

/// Compagnon de run (GDD diapo 9 : « il l'accompagne et lui donne un boost ») : la créature ou le
/// héros choisi suit l'explorateur dans le monde. Logique pure (sans Flame), testée.

/// Exemplaire qui accompagne le joueur : son plus bel exemplaire de l'espèce choisie (étoiles de
/// l'apparence, puis stats, comme « Mes plus belles trouvailles »). Null s'il n'en a aucun.
// PROVISOIRE : on ne choisit pas encore l'exemplaire (seulement l'espèce) ; question à Clem.
CardInstance? companionInstance(GameCard card, List<int>? seeds) {
  if (seeds == null || seeds.isEmpty) return null;
  CardInstance? best;
  for (final s in seeds) {
    final inst = CardInstance(card, s);
    if (best == null || findScore(inst) > findScore(best)) best = inst;
  }
  return best;
}

/// Hauteur du compagnon à l'écran (unités du monde) : un peu plus grand selon la rareté de l'espèce,
/// puis à la taille de l'exemplaire (±10 %, GDD diapo 13).
double companionHeight(CardInstance inst) =>
    (GameConfig.companionHeight + inst.card.rarity.index * GameConfig.companionHeightPerRarity) *
    inst.variant.sizeMult;

/// Déplacement du compagnon : il vise un point juste derrière l'explorateur (côté opposé à son
/// regard, légèrement décalé sur le côté), le rejoint d'autant plus vite qu'il en est loin, et
/// réapparaît à côté de lui s'il a été distancé (esquive, chute…). Il traverse tout (vole un peu).
class CompanionFollower {
  CompanionFollower(this.x, this.y);

  double x;
  double y;

  /// Le compagnon regarde vers la gauche (illustration retournée).
  bool facingLeft = false;

  /// Il se déplace en ce moment (petits bonds).
  bool moving = false;

  /// Temps restant du saut de joie (carte gagnée), en secondes.
  double cheer = 0;

  /// Nombre de fois où il a été replacé à côté du joueur (pour les tests et le débogage).
  int teleports = 0;

  /// Point visé : derrière le joueur, à [GameConfig.companionFollowDistance], un peu sur le côté.
  (double, double) target(double px, double py, double fx, double fy) {
    final len = math.sqrt(fx * fx + fy * fy);
    final (dx, dy) = len < 1e-6 ? (1.0, 0.0) : (fx / len, fy / len);
    const d = GameConfig.companionFollowDistance;
    // Perpendiculaire (vers le bas de l'écran de préférence, pour ne pas cacher le joueur).
    var (sx, sy) = (-dy, dx);
    if (sy < 0) (sx, sy) = (-sx, -sy);
    return (px - dx * d + sx * d * 0.4, py - dy * d + sy * d * 0.4);
  }

  /// Avance d'un pas de [dt] secondes vers le joueur en ([px], [py]) qui regarde vers ([fx], [fy]).
  void update(double dt, double px, double py, double fx, double fy) {
    cheer = math.max(0, cheer - dt);
    final (tx, ty) = target(px, py, fx, fy);
    final dx = tx - x, dy = ty - y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final fromPlayer = math.sqrt((px - x) * (px - x) + (py - y) * (py - y));
    if (fromPlayer > GameConfig.companionTeleportDistance) {
      x = tx;
      y = ty;
      teleports++;
      moving = false;
      return;
    }
    if (dist < GameConfig.companionArriveDistance) {
      moving = false;
      return;
    }
    // Rattrape plus vite quand il est loin, sans jamais dépasser la cible.
    final speed = math.max(GameConfig.companionMinSpeed, dist * GameConfig.companionCatchUp);
    final step = math.min(dist, speed * dt);
    x += dx / dist * step;
    y += dy / dist * step;
    moving = true;
    if (dx.abs() > 2) facingLeft = dx < 0;
  }

  /// Petit saut de joie (carte gagnée, lieu terminé).
  void celebrate() => cheer = GameConfig.companionCheerDuration;

  /// Hauteur du saut (unités du monde) : saut de joie, sinon petits bonds en marchant ; [t] = temps de la run.
  double hop(double t) {
    if (cheer > 0) {
      final p = 1 - cheer / GameConfig.companionCheerDuration; // 0 → 1
      return math.sin(p * math.pi) * 10;
    }
    if (moving) return math.sin(t * 14).abs() * 4;
    return (math.sin(t * 2.5) + 1) * 1.2; // flotte doucement sur place
  }
}

/// Haut du dessin d'une illustration (là où se pose l'accessoire du compagnon), en fractions de
/// l'image : [top] = première ligne vraiment dessinée (0 = haut), [x] = milieu du dessin juste
/// en dessous (médiane des pixels opaques sur [GameConfig.accessoryHeadBand] de la hauteur).
class HeadAnchor {
  const HeadAnchor(this.x, this.top);
  final double x;
  final double top;

  /// Pour une illustration absente (rond de couleur) : haut du rond.
  static const fallback = HeadAnchor(0.5, 0.2);
}

/// Cherche le haut du dessin dans des pixels RGBA ([w] × [h], 4 octets par pixel, fond transparent).
/// Une ligne compte quand au moins 1 % de ses pixels sont opaques (ignore les poussières isolées).
/// Renvoie [HeadAnchor.fallback] si l'image est vide ou mal formée.
HeadAnchor findHeadAnchor(Uint8List rgba, int w, int h, {int alphaMin = 128}) {
  if (w <= 0 || h <= 0 || rgba.length < w * h * 4) return HeadAnchor.fallback;
  final minCount = math.max(2, (w * 0.01).floor());
  int? top;
  for (var y = 0; y < h && top == null; y++) {
    var n = 0;
    for (var x = 0; x < w; x++) {
      if (rgba[(y * w + x) * 4 + 3] >= alphaMin) n++;
    }
    if (n >= minCount) top = y;
  }
  if (top == null) return HeadAnchor.fallback;
  final band = math.max(1, (h * GameConfig.accessoryHeadBand).round());
  final xs = <int>[];
  for (var y = top; y < math.min(h, top + band); y++) {
    for (var x = 0; x < w; x++) {
      if (rgba[(y * w + x) * 4 + 3] >= alphaMin) xs.add(x);
    }
  }
  xs.sort();
  final mx = xs[xs.length ~/ 2];
  return HeadAnchor((mx + 0.5) / w, top / h);
}
