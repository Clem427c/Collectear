import 'cards.dart';
import 'config.dart';

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
}

/// État logique d'une run (indépendant du moteur, testé unitairement).
class RunState {
  RunState(this.rules);

  final RunRules rules;
  double elapsed = 0;
  int kills = 0;
  int hitsTaken = 0;
  final List<GameCard> cards = [];
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

  /// Enregistre un ennemi tué. Renvoie true si ce kill débloque une carte.
  bool registerKill() {
    if (isOver) return false;
    kills++;
    return kills % GameConfig.killsPerCard == 0;
  }

  /// Ajoute une carte ; la run se termine à la 3e.
  void addCard(GameCard card) {
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

  void quit() => endReason ??= RunEndReason.quit;
}
