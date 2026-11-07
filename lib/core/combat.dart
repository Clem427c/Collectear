import 'dart:math' as math;

import 'config.dart';

/// Règle de l'attaque du joueur (logique pure, testée).
///
/// Un ennemi est touché s'il est à portée ET devant le joueur (cône de ~78° de chaque côté).
/// Retour de Clem du 28/10 : collé à un ennemi ou en le chevauchant, le coup était trop aléatoire ;
/// au contact, l'ennemi est maintenant touché quelle que soit la direction du joueur.
///
/// [dx], [dy] : vecteur joueur → ennemi ; [facingX], [facingY] : direction du regard (unitaire) ;
/// [range] : portée de l'attaque ; [enemyRadius] : rayon de l'ennemi.
bool playerAttackHits({
  required double dx,
  required double dy,
  required double facingX,
  required double facingY,
  required double range,
  required double enemyRadius,
}) {
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist <= GameConfig.attackContactDistance) return true; // collé ou chevauché : toujours touché
  if (dist > range + enemyRadius) return false;
  return (dx * facingX + dy * facingY) / dist >= GameConfig.attackArcCos;
}

/// Bulle « ! » d'un ennemi qui repère le joueur (GDD diapo 8, état « Détection »). Logique pure, testée.
class DetectionAlert {
  /// Temps restant d'affichage du « ! » (0 = rien d'affiché).
  double remaining = 0;

  /// Temps écoulé depuis la dernière fois que l'ennemi a perdu le joueur de vue.
  double _sinceLost = double.infinity;

  /// Le « ! » est-il affiché ?
  bool get visible => remaining > 0;

  /// Avancement de l'animation, de 0 (apparition) à 1 (disparition).
  double get progress => visible ? 1 - remaining / GameConfig.detectAlertDuration : 1;

  /// L'ennemi vient de repérer le joueur. Renvoie vrai si le « ! » s'affiche.
  bool spotted() {
    if (_sinceLost < GameConfig.detectAlertCooldown) return false;
    remaining = GameConfig.detectAlertDuration;
    return true;
  }

  /// L'ennemi vient de perdre le joueur de vue.
  void lost() => _sinceLost = 0;

  void update(double dt) {
    remaining = math.max(0, remaining - dt);
    if (_sinceLost.isFinite) _sinceLost += dt;
  }
}
