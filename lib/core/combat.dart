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
