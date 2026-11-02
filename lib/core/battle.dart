// Pure Dart auto-battle core. No Flutter or Flame imports.
// Prototype rules (placeholder balance): speed order, one action per turn.
// A ready skill is used instead of a basic attack. Ultimates come later.

import 'dart:math' show max, min;

import 'models.dart';

enum Side { heroes, enemies }

enum EventKind { attack, heal, stun, skip, taunt, buff }

class Combatant {
  Combatant(this.unit, this.side)
      : hp = unit.baseStats.hp,
        cooldowns = {for (final s in unit.skills) s.id: 0};

  final Unit unit;
  final Side side;
  final Map<String, int> cooldowns;
  int hp;
  int stunTurns = 0;
  int tauntTurns = 0;
  int buffTurns = 0;
  double buffPct = 0;

  bool get alive => hp > 0;

  int get atk =>
      (unit.baseStats.atk * (1 + (buffTurns > 0 ? buffPct : 0))).round();
}

/// One action. Indexes refer to the combined list [heroes..., enemies...].
/// [amount] = damage, healed HP, or stun duration depending on [kind].
class BattleEvent {
  const BattleEvent({
    required this.round,
    required this.actorIndex,
    required this.targetIndex,
    required this.kind,
    required this.amount,
    required this.targetHpAfter,
    this.skillId,
  });

  final int round;
  final int actorIndex;
  final int targetIndex;
  final EventKind kind;
  final int amount;
  final int targetHpAfter;
  final String? skillId;
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

/// A taunting unit is hit first; then melee units; otherwise any living unit.
Combatant? pickTarget(List<Combatant> targets) {
  final alive = targets.where((c) => c.alive).toList();
  if (alive.isEmpty) return null;
  final taunting = alive.where((c) => c.tauntTurns > 0).toList();
  if (taunting.isNotEmpty) return taunting.first;
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
  var round = 0;

  bool sideAlive(List<Combatant> s) => s.any((c) => c.alive);

  void emit(EventKind kind, Combatant actor, Combatant target, int amount,
      {String? skillId}) {
    events.add(BattleEvent(
      round: round,
      actorIndex: all.indexOf(actor),
      targetIndex: all.indexOf(target),
      kind: kind,
      amount: amount,
      targetHpAfter: target.hp,
      skillId: skillId,
    ));
    log.add('R$round ${actor.unit.id} ${kind.name}'
        '${skillId == null ? '' : '($skillId)'} -> ${target.unit.id}: '
        '$amount (hp ${target.hp})');
  }

  void hit(Combatant actor, Combatant target, int atk, {String? skillId}) {
    final dmg = calcDamage(atk, target.unit.baseStats.def);
    target.hp = max(0, target.hp - dmg);
    emit(EventKind.attack, actor, target, dmg, skillId: skillId);
  }

  /// Returns true if the skill was used (so it goes on cooldown).
  bool useSkill(Combatant actor, Skill skill, List<Combatant> allies,
      List<Combatant> foes) {
    switch (skill.type) {
      case SkillType.none:
        return false;
      case SkillType.damageMulti:
        final alive = foes.where((c) => c.alive).toList();
        if (alive.isEmpty) return false;
        var target = alive.first;
        for (final c in alive) {
          if (c.hp < target.hp) target = c;
        }
        final atk = (actor.atk * skill.power).round();
        for (var i = 0; i < skill.hits && target.alive; i++) {
          hit(actor, target, atk, skillId: skill.id);
        }
        return true;
      case SkillType.heal:
        Combatant? target;
        for (final c in allies) {
          final maxHp = c.unit.baseStats.hp;
          if (!c.alive || c.hp >= maxHp) continue;
          if (target == null ||
              c.hp / maxHp < target.hp / target.unit.baseStats.hp) {
            target = c;
          }
        }
        if (target == null) return false;
        final maxHp = target.unit.baseStats.hp;
        final amount = min(maxHp - target.hp, (maxHp * skill.power).round());
        target.hp += amount;
        emit(EventKind.heal, actor, target, amount, skillId: skill.id);
        return true;
      case SkillType.taunt:
        actor.tauntTurns = skill.duration;
        emit(EventKind.taunt, actor, actor, skill.duration, skillId: skill.id);
        return true;
      case SkillType.stun:
        final target = pickTarget(foes);
        if (target == null) return false;
        hit(actor, target, actor.atk, skillId: skill.id);
        if (target.alive) {
          target.stunTurns += skill.duration;
          emit(EventKind.stun, actor, target, skill.duration,
              skillId: skill.id);
        }
        return true;
      case SkillType.buffAtk:
        for (final c in allies) {
          if (!c.alive) continue;
          c.buffPct = skill.power;
          c.buffTurns = skill.duration;
          emit(EventKind.buff, actor, c, skill.duration, skillId: skill.id);
        }
        return true;
    }
  }

  while (round < maxRounds && sideAlive(hs) && sideAlive(es)) {
    round++;
    // Stable sort: higher speed first, ties keep list order (heroes first).
    final order = [...all]..sort((a, b) {
        final bySpd = b.unit.baseStats.spd.compareTo(a.unit.baseStats.spd);
        return bySpd != 0 ? bySpd : all.indexOf(a).compareTo(all.indexOf(b));
      });
    for (final actor in order) {
      if (!actor.alive) continue;
      final allies = actor.side == Side.heroes ? hs : es;
      final foes = actor.side == Side.heroes ? es : hs;
      if (!sideAlive(foes)) break;

      // Start of own turn: tick timers.
      actor.cooldowns.updateAll((_, v) => v > 0 ? v - 1 : 0);
      if (actor.tauntTurns > 0) actor.tauntTurns--;
      if (actor.buffTurns > 0) actor.buffTurns--;

      if (actor.stunTurns > 0) {
        actor.stunTurns--;
        emit(EventKind.skip, actor, actor, 0);
        continue;
      }

      var acted = false;
      for (final skill in actor.unit.skills) {
        if ((actor.cooldowns[skill.id] ?? 0) > 0) continue;
        if (useSkill(actor, skill, allies, foes)) {
          actor.cooldowns[skill.id] = skill.cooldown;
          acted = true;
          break;
        }
      }
      if (!acted) {
        final target = pickTarget(foes);
        if (target == null) break;
        hit(actor, target, actor.atk);
      }
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
