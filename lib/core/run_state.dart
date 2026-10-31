import 'cards.dart';
import 'config.dart';
import 'variants.dart';

enum RunEndReason { death, cardsCollected, timeUp, quit }

extension RunEndReasonInfo on RunEndReason {
  String get label => const [
        'Tu es tombé au combat',
        'Run réussie : 3 cartes trouvées !',
        'Temps écoulé',
        'Run abandonnée',
      ][index];
}

/// Règles d'une run, en fonction du compagnon choisi.
class RunRules {
  const RunRules({this.boost});

  final Boost? boost;

  double get duration => GameConfig.runDuration + (boost == Boost.time ? GameConfig.timeBoostSeconds : 0);
  int get enemyHitsToKill =>
      boost == Boost.damage ? GameConfig.enemyHitsToKillBoosted : GameConfig.enemyHitsToKill;
  int get playerHitsToDie =>
      boost == Boost.resistance ? GameConfig.playerHitsToDieBoosted : GameConfig.playerHitsToDie;
  double get speedMultiplier => boost == Boost.speed ? GameConfig.speedBoostMultiplier : 1.0;
  double get attackRange => boost == Boost.range ? GameConfig.attackRangeBoosted : GameConfig.attackRange;
}

/// État logique d'une run (indépendant du moteur, testé unitairement).
class RunState {
  RunState(this.rules);

  final RunRules rules;
  double elapsed = 0;
  int kills = 0;
  int hitsTaken = 0;

  /// Plus grande distance au point de départ atteinte pendant la run, en cases (à vol d'oiseau).
  double maxDistanceTiles = 0;

  /// Lieux débloqués pendant la run (sanctuaire, tour, ruine, coffre).
  int placesFound = 0;

  /// Record de distance de la run, en mètres (arrondi à l'inférieur).
  int get distanceMeters => (maxDistanceTiles * GameConfig.metersPerTile).floor();

  /// Position du joueur, en cases depuis le point de départ (ignorée une fois la run terminée).
  void trackDistance(double tilesFromStart) {
    if (isOver || !tilesFromStart.isFinite) return;
    if (tilesFromStart > maxDistanceTiles) maxDistanceTiles = tilesFromStart;
  }

  /// Un lieu vient d'être débloqué.
  void registerPlace() {
    if (isOver) return;
    placesFound++;
  }

  /// Pièces ramassées pendant la run (ajoutées au porte-monnaie à la fin, même en cas de défaite).
  int coins = 0;
  final List<CardInstance> cards = [];
  RunEndReason? endReason;

  bool get isOver => endReason != null;
  double get remaining => (rules.duration - elapsed).clamp(0, rules.duration).toDouble();
  int get hitsLeft => rules.playerHitsToDie - hitsTaken;
  int get killsTowardNextCard => kills % GameConfig.killsPerCard;

  void tick(double dt) {
    if (isOver) return;
    elapsed += dt;
    if (elapsed >= rules.duration) {
      elapsed = rules.duration;
      endReason = RunEndReason.timeUp;
    }
  }

  /// Nombre de vies rendues pendant la run.
  int livesRegained = 0;

  /// Enregistre un ennemi tué. Renvoie true si ce kill débloque une carte.
  /// Tous les 3 kills, une vie perdue est rendue.
  bool registerKill() {
    if (isOver) return false;
    kills++;
    if (kills % GameConfig.killsPerLifeRegen == 0 && hitsTaken > 0) {
      hitsTaken--;
      livesRegained++;
    }
    return kills % GameConfig.killsPerCard == 0;
  }

  /// Ajoute une carte ; la run se termine à la 3e.
  void addCard(CardInstance card) {
    if (isOver) return;
    cards.add(card);
    if (cards.length >= GameConfig.maxCardsPerRun) endReason = RunEndReason.cardsCollected;
  }

  /// Le joueur encaisse un coup. Renvoie true s'il meurt.
  bool playerHit() {
    if (isOver) return false;
    hitsTaken++;
    if (hitsTaken >= rules.playerHitsToDie) {
      endReason = RunEndReason.death;
      return true;
    }
    return false;
  }

  /// Ajoute des pièces (ignoré une fois la run terminée).
  void addCoins(int amount) {
    if (isOver || amount <= 0) return;
    coins += amount;
  }

  /// Résurrections utilisées (vidéo récompensée à la mort).
  int revives = 0;

  /// On peut proposer une résurrection : mort (pas abandon ni chrono), il reste du temps,
  /// et la limite par run n'est pas atteinte.
  bool get canRevive =>
      endReason == RunEndReason.death && revives < GameConfig.revivesPerRun && remaining > 0;

  /// Ressuscite le joueur avec GameConfig.reviveLives vie(s). Renvoie false si ce n'est pas permis.
  bool revive() {
    if (!canRevive) return false;
    revives++;
    endReason = null;
    hitsTaken = rules.playerHitsToDie - GameConfig.reviveLives;
    return true;
  }

  void quit() => endReason ??= RunEndReason.quit;
}
