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

  // --- Records d'exploration (GDD diapo 12 : « record de distance, lieux découverts ») ---
  /// PROVISOIRE : 1 case = 1 mètre (le personnage fait environ une case ; ≈ 3,75 m/s en marchant).
  static const double metersPerTile = 1;

  /// Plafond de vraisemblance côté serveur (finish_run) : cases par seconde au plus, esquives comprises.
  /// Le joueur avance à 3,75 cases/s (5 avec le boost Vitesse) ; l'esquive va plus vite mais peu longtemps.
  static const int maxTilesPerSecond = 8;

  // --- Variantes rares selon la chance (GDD diapos 5 et 10) ---
  /// « Plus on s'éloigne, plus les variantes sont rares » ; « coffre rare : meilleures chances de variante rare ».
  /// Validé par Clem le 03/11 : avec une chance (distance + bonus du lieu) de 1, on tire jusqu'à 1 + 2 = 3 apparences et on
  /// garde la plus rare (Shiny ≈ 2,5 % → ≈ 7,3 % ; finition ≈ 2,3 % → ≈ 6,8 %). Les stats ne sont pas favorisées.
  static const int variantLuckExtraDraws = 2;

  // --- Taille des variantes (GDD diapo 13 : « taille et stats légèrement modifiées ») ---
  /// PROVISOIRE (question à Clem) : chaque exemplaire est jusqu'à 10 % plus petit ou plus grand que son espèce.
  /// Purement visuel : la taille ne change ni les stats, ni les étoiles, ni le tirage.
  static const double variantSizeSpread = 0.10;
  /// Au-delà de cet écart (en %), l'exemplaire est dit « petit » ou « grand » (sinon « moyen »).
  static const int variantSizeLabelThreshold = 5;

  // --- Combat ---
  static const int enemyHitsToKill = 3;
  static const int enemyHitsToKillBoosted = 2;
  static const int playerHitsToDie = 3; // 3 vies
  static const int playerHitsToDieBoosted = 4; // boost résistance : +1 vie
  static const int killsPerLifeRegen = 3; // 1 vie rendue tous les 3 kills (si une vie a été perdue)

  // --- Compagnon dessiné en run (GDD diapo 9 : « il l'accompagne ») ---
  /// PROVISOIRE : le compagnon suit l'explorateur à un peu plus d'une case derrière lui, traverse tout,
  /// ne se bat pas (son seul effet reste le boost) et réapparaît à côté du joueur s'il est distancé.
  static const double companionFollowDistance = 1.1 * tileSize;
  static const double companionArriveDistance = 4;
  static const double companionMinSpeed = 60; // unités / s
  static const double companionCatchUp = 4; // vitesse = distance × 4 par seconde
  static const double companionTeleportDistance = 7 * tileSize;
  static const double companionHeight = 28; // espèce Commune (l'explorateur fait 40)
  static const double companionHeightPerRarity = 2; // +2 par rang de rareté (Légendaire : 36)
  static const double companionCheerDuration = 0.6; // saut de joie quand une carte est gagnée
  // Accessoire du compagnon (PROVISOIRE) : posé sur le haut du dessin, dont le milieu est cherché
  // dans une bande de 8 % de la hauteur de l'illustration.
  static const double accessoryHeadBand = 0.08;

  // --- Joueur ---
  static const double playerSpeed = 120; // unités / s
  static const double speedBoostMultiplier = 1.35;
  static const double jumpDuration = 0.45;
  static const double jumpHeight = 18; // décalage visuel
  static const double attackCooldown = 0.35;
  static const double attackRange = 40;
  static const double attackRangeBoosted = 68; // boost Portée
  static const double attackArcCos = 0.2; // ~78° de chaque côté
  /// Distance (centre à centre) en dessous de laquelle le joueur est collé à l'ennemi ou le chevauche :
  /// le coup touche alors dans toutes les directions (retour de Clem du 28/10). Les dessins font
  /// environ une case ; 28 = les deux silhouettes se touchent.
  static const double attackContactDistance = 28;
  static const int attackMaxLevelDiff = 1; // on touche une cible un étage plus haut ou plus bas
  static const double dodgeDuration = 0.22;
  static const double dodgeSpeed = 360;
  static const double dodgeCooldown = 0.9;
  static const double invincibleAfterHit = 1.0;

  // --- Décors solides (PROVISOIRE, question à Clem ; désactivables dans ⚙ Paramètres) ---
  /// Rayon de l'obstacle au pied d'un arbre ou d'un rocher (le tronc, pas le feuillage).
  /// Avec le rayon du joueur (9), il reste largement la place de passer dans la case voisine.
  static const double propSolidRadius = 8;
  static const bool solidDecorDefault = true;

  // --- Ennemis ---
  static const double startGrace = 4; // secondes sans agression au début de la run
  static const double meleeSpeed = 70;
  static const double rangedSpeed = 60;
  static const double detectRadius = 5 * tileSize;

  /// Détection (GDD diapo 8 : patrouille → détection → poursuite) : un « ! » apparaît au-dessus de
  /// l'ennemi qui vient de repérer le joueur, pendant [detectAlertDuration] secondes. Purement visuel.
  /// Un ennemi qui perd le joueur de vue puis le retrouve dans les [detectAlertCooldown] secondes
  /// ne le refait pas (pas de clignotement au bord du rayon de détection).
  static const double detectAlertDuration = 0.7;
  static const double detectAlertCooldown = 3;
  static const double meleeRange = 30;
  static const double meleeTelegraph = 0.5;
  static const double rangedPreferredDistance = 4.5 * tileSize;
  static const double rangedTelegraph = 0.6;
  static const double rangedCooldown = 1.6;
  static const double projectileSpeed = 170;
  static const double projectileLife = 2.5;
  static const double enemyAttackCooldown = 1.1;

  // --- Publicités récompensées (GDD diapo 15 ; voir core/ads.dart) ---
  // PROVISOIRE (à valider par Clem) : 3 runs bonus par jour, une seule résurrection par run.
  static const int adBonusRunsPerDay = 3; // vidéo = +1 run, seulement quand il n'en reste plus
  static const int revivesPerRun = 1; // vidéo à la mort = on repart
  static const int reviveLives = 1; // vies rendues par la résurrection
  static const double reviveInvincibility = 2.5; // secondes intouchable après la résurrection

  // --- Espèces des biomes (GDD diapo 11 : « chaque biome a ses espèces » ; voir core/cards.dart) ---
  // PROVISOIRE (question à Clem) : dans un biome, ses espèces pèsent 3 fois plus que les autres
  // (≈ 60 % des cartes tirées viennent du biome) ; toutes les cartes restent trouvables partout.
  static const double biomeSpeciesBias = 3;
}
