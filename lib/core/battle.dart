// Pure Dart auto-battle core. No Flutter or Flame imports.
// Prototype rules (placeholder balance): speed order, basic attacks only.
// Skills, status effects and ultimates come next.

import 'models.dart';

enum Side { heroes, enemies }

class Combatant {
  Combatant(this.unit, this.side) : hp = unit.baseStats.hp;

  final Unit unit;
  final Side side;
  int hp;

  bool get alive => hp > 0;
}

/// One attack. Indexes refer to the combined list [heroes..., enemies...].
class BattleEvent {
  const BattleEvent({
    required this.round,
    required this.actorIndex,
    required this.targetIndex,
    required this.damage,
    required this.targetHpAfter,
  });

  final int round;
  final int actorIndex;
  final int targetIndex;
  final int damage;
  final int targetHpAfter;
}

class BattleResult {
  const BattleResult({
    required this.winner,
    required this.rounds,
    required this.log,
    required this.events,
  });

  /// null = draw (round limit reached).
  final Side? winner;
  final int rounds;
  final List<String> log;
  final List<BattleEvent> events;
}

int calcDamage(int atk, int def) {
  final dmg = atk - def ~/ 2;
  return dmg < 1 ? 1 : dmg;
}

/// Melee units on the opposing side are hit first; otherwise any living unit.
Combatant? pickTarget(List<Combatant> targets) {
  final alive = targets.where((c) => c.alive).toList();
  if (alive.isEmpty) return null;
  final front = alive.where((c) => c.unit.range == Range.melee).toList();
  return front.isNotEmpty ? front.first : alive.first;
}

/// Deterministic: same input always gives the same result.
BattleResult simulateBattle(
  List<Unit> heroes,
  List<Unit> enemies, {
  int maxRounds = 50,
}) {
  final hs = [for (final u in heroes) Combatant(u, Side.heroes)];
  final es = [for (final u in enemies) Combatant(u, Side.enemies)];
  final all = [...hs, ...es];
  final log = <String>[];
  final events = <BattleEvent>[];

  bool sideAlive(List<Combatant> s) => s.any((c) => c.alive);

  var round = 0;
  while (round < maxRounds && sideAlive(hs) && sideAlive(es)) {
    round++;
    // Stable sort: higher speed first, ties keep list order (heroes first).
    final order = [...all]..sort((a, b) {
        final bySpd = b.unit.baseStats.spd.compareTo(a.unit.baseStats.spd);
        return bySpd != 0 ? bySpd : all.indexOf(a).compareTo(all.indexOf(b));
      });
    for (final actor in order) {
      if (!actor.alive) continue;
      final target = pickTarget(actor.side == Side.heroes ? es : hs);
      if (target == null) break;
      final dmg =
          calcDamage(actor.unit.baseStats.atk, target.unit.baseStats.def);
      target.hp = target.hp - dmg < 0 ? 0 : target.hp - dmg;
      log.add('R$round ${actor.unit.id} -> ${target.unit.id}: $dmg '
          '(hp ${target.hp})');
      events.add(BattleEvent(
        round: round,
        actorIndex: all.indexOf(actor),
        targetIndex: all.indexOf(target),
        damage: dmg,
        targetHpAfter: target.hp,
      ));
    }
  }

  final Side? winner = !sideAlive(es) && sideAlive(hs)
      ? Side.heroes
      : !sideAlive(hs) && sideAlive(es)
          ? Side.enemies
          : null;
  return BattleResult(
      winner: winner, rounds: round, log: log, events: events);
}
