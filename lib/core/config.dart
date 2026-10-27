/// Constantes de gameplay (voir docs/ et ROADMAP.md).
class GameConfig {
  GameConfig._();

  /// Taille d'une case du monde, en unités du monde.
  static const double tileSize = 32;

  /// Taille d'un chunk en cases (spawn/despawn des entités).
  static const int chunkTiles = 8;

  /// Nombre de niveaux de hauteur (0 .. maxLevel).
  static const int maxLevel = 4;

  // --- Run ---
  static const double runDuration = 120; // secondes
  static const double timeBoostSeconds = 30;
  static const int hurrySeconds = 15; // chrono en alerte (rouge, au centre, son)
  static const int maxCardsPerRun = 3;
  static const int killsPerCard = 10;
  static const int runsPerDay = 10;

  // --- Combat ---
  static const int enemyHitsToKill = 3;
  static const int enemyHitsToKillBoosted = 2;
  static const int playerHitsToDie = 3; // 3 vies
  static const int playerHitsToDieBoosted = 4; // boost résistance : +1 vie
  static const int killsPerLifeRegen = 3; // 1 vie rendue tous les 3 kills (si une vie a été perdue)

  // --- Joueur ---
  static const double playerSpeed = 120; // unités / s
  static const double speedBoostMultiplier = 1.35;
  static const double jumpDuration = 0.45;
  static const double jumpHeight = 18; // décalage visuel
  static const double attackCooldown = 0.35;
  static const double attackRange = 40;
  static const double attackRangeBoosted = 68; // boost Portée
  static const double attackArcCos = 0.2; // ~78° de chaque côté
  static const int attackMaxLevelDiff = 1; // on touche une cible un étage plus haut ou plus bas
  static const double dodgeDuration = 0.22;
  static const double dodgeSpeed = 360;
  static const double dodgeCooldown = 0.9;
  static const double invincibleAfterHit = 1.0;

  // --- Ennemis ---
  static const double startGrace = 4; // secondes sans agression au début de la run
  static const double meleeSpeed = 70;
  static const double rangedSpeed = 60;
  static const double detectRadius = 5 * tileSize;
  static const double meleeRange = 30;
  static const double meleeTelegraph = 0.5;
  static const double rangedPreferredDistance = 4.5 * tileSize;
  static const double rangedTelegraph = 0.6;
  static const double rangedCooldown = 1.6;
  static const double projectileSpeed = 170;
  static const double projectileLife = 2.5;
  static const double enemyAttackCooldown = 1.1;
}
