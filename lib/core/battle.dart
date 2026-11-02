// Pure Dart auto-battle core. No Flutter or Flame imports.
// Prototype rules (placeholder balance): speed order, one action per turn.
// A ready skill is used instead of a basic attack. Energy fills from acting
// and from taking hits; at full energy the ultimate is cast (enemies and
// AUTO mode cast on their own, otherwise the player queues it).

import 'dart:math' show max, min;

import 'models.dart';

enum Side { heroes, enemies }

enum EventKind {
  attack,
  heal,
  stun,
  skip,
  taunt,
  buff,
  shield,
  reflect,
  silence,
}

const int maxEnergy = 100;
const int _energyPerAction = 25;
const int _energyPerHit = 15;

class Combatant {
  Combatant(this.unit, this.side)
      : hp = unit.baseStats.hp,
        cooldowns = {for (final s in unit.skills) s.id: 0};

  final Unit unit;
  final Side side;
  final Map<String, int> cooldowns;
  int hp;
  int energy = 0;
  bool ultQueued = false;
  int stunTurns = 0;
  int tauntTurns = 0;
  int buffTurns = 0;
  double buffPct = 0;
  int silenceTurns = 0;
  int reflectTurns = 0;
  double reflectPct = 0;
  int shield = 0;

  bool get alive => hp > 0;

  bool get ultReady => unit.ultimate != null && energy >= maxEnergy;

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

/// Steppable battle. Call [step] to run one actor's action and get the events
/// it produced. Deterministic for the same units and the same player input.
class Battle {
  Battle(List<Unit> heroes, List<Unit> enemies, {this.maxRounds = 50})
      : hs = [for (final u in heroes) Combatant(u, Side.heroes)],
        es = [for (final u in enemies) Combatant(u, Side.enemies)] {
    all = [...hs, ...es];
  }

  final int maxRounds;
  final List<Combatant> hs;
  final List<Combatant> es;
  late final List<Combatant> all;

  /// AUTO mode: heroes cast their ultimate as soon as energy is full.
  bool auto = false;

  final List<String> log = [];
  final List<BattleEvent> events = [];
  int round = 0;

  List<Combatant> _queue = [];
  int _cursor = 0;

  bool _sideAlive(List<Combatant> s) => s.any((c) => c.alive);

  bool get finished =>
      !_sideAlive(hs) ||
      !_sideAlive(es) ||
      (round >= maxRounds && _cursor >= _queue.length);

  Side? get winner => !_sideAlive(es) && _sideAlive(hs)
      ? Side.heroes
      : !_sideAlive(hs) && _sideAlive(es)
          ? Side.enemies
          : null;

  BattleResult get result => BattleResult(
        winner: winner,
        rounds: round,
        log: log,
        events: events,
      );

  /// Marks a hero's ultimate to be cast on its next turn with full energy.
  void queueUltimate(int index) {
    if (index < 0 || index >= hs.length) return;
    final c = all[index];
    if (c.alive && c.unit.ultimate != null) c.ultQueued = true;
  }

  /// Runs the next action. Returns the events it produced (empty if finished).
  List<BattleEvent> step() {
    final start = events.length;
    while (!finished && events.length == start) {
      if (_cursor >= _queue.length) {
        round++;
        // Stable sort: higher speed first, ties keep list order (heroes first).
        _queue = [...all]..sort((a, b) {
            final bySpd = b.unit.baseStats.spd.compareTo(a.unit.baseStats.spd);
            return bySpd != 0
                ? bySpd
                : all.indexOf(a).compareTo(all.indexOf(b));
          });
        _cursor = 0;
      }
      final actor = _queue[_cursor++];
      if (!actor.alive) continue;
      _act(actor);
    }
    return events.sublist(start);
  }

  void _emit(EventKind kind, Combatant actor, Combatant target, int amount,
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

  void _hit(Combatant actor, Combatant target, int atk, {String? skillId}) {
    final dmg = calcDamage(atk, target.unit.baseStats.def);
    final absorbed = min(target.shield, dmg);
    target.shield -= absorbed;
    final taken = dmg - absorbed;
    target.hp = max(0, target.hp - taken);
    if (target.alive) {
      target.energy = min(maxEnergy, target.energy + _energyPerHit);
    }
    _emit(EventKind.attack, actor, target, taken, skillId: skillId);

    // Reflect: part of the damage taken goes back (no chain reaction).
    if (target.reflectTurns > 0 && taken > 0 && actor.alive) {
      final back = (taken * target.reflectPct).round();
      if (back > 0) {
        actor.hp = max(0, actor.hp - back);
        _emit(EventKind.attack, target, actor, back);
      }
    }
  }

  int _heal(Combatant actor, Combatant target, double fraction,
      {String? skillId}) {
    final maxHp = target.unit.baseStats.hp;
    final amount = min(maxHp - target.hp, (maxHp * fraction).round());
    target.hp += amount;
    _emit(EventKind.heal, actor, target, amount, skillId: skillId);
    return amount;
  }

  void _act(Combatant actor) {
    final allies = actor.side == Side.heroes ? hs : es;
    final foes = actor.side == Side.heroes ? es : hs;

    // Start of own turn: tick timers.
    actor.cooldowns.updateAll((_, v) => v > 0 ? v - 1 : 0);
    if (actor.tauntTurns > 0) actor.tauntTurns--;
    if (actor.buffTurns > 0) actor.buffTurns--;
    if (actor.reflectTurns > 0) actor.reflectTurns--;

    if (actor.stunTurns > 0) {
      actor.stunTurns--;
      _emit(EventKind.skip, actor, actor, 0);
      return;
    }

    // Silenced units can only use basic attacks.
    final silenced = actor.silenceTurns > 0;
    if (silenced) actor.silenceTurns--;

    final ult = actor.unit.ultimate;
    if (!silenced &&
        ult != null &&
        actor.energy >= maxEnergy &&
        (actor.side == Side.enemies || auto || actor.ultQueued)) {
      if (_useSkill(actor, ult, allies, foes)) {
        actor.energy = 0;
        actor.ultQueued = false;
        return;
      }
    }

    var acted = false;
    for (final skill in actor.unit.skills) {
      if (silenced) break;
      if ((actor.cooldowns[skill.id] ?? 0) > 0) continue;
      if (_useSkill(actor, skill, allies, foes)) {
        actor.cooldowns[skill.id] = skill.cooldown;
        acted = true;
        break;
      }
    }
    if (!acted) {
      final target = pickTarget(foes);
      if (target == null) return;
      _hit(actor, target, actor.atk);
    }
    actor.energy = min(maxEnergy, actor.energy + _energyPerAction);
  }

  /// Returns true if the skill was used.
  bool _useSkill(Combatant actor, Skill skill, List<Combatant> allies,
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
        for (var i = 0; i < skill.hits && target.alive && actor.alive; i++) {
          _hit(actor, target, atk, skillId: skill.id);
        }
        return true;
      case SkillType.damageAll:
        final alive = foes.where((c) => c.alive).toList();
        if (alive.isEmpty) return false;
        final atk = (actor.atk * skill.power).round();
        for (final c in alive) {
          if (!actor.alive) break;
          _hit(actor, c, atk, skillId: skill.id);
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
        _heal(actor, target, skill.power, skillId: skill.id);
        return true;
      case SkillType.healAll:
        var healed = false;
        for (final c in allies) {
          if (!c.alive || c.hp >= c.unit.baseStats.hp) continue;
          _heal(actor, c, skill.power, skillId: skill.id);
          healed = true;
        }
        return healed;
      case SkillType.taunt:
        actor.tauntTurns = skill.duration;
        _emit(EventKind.taunt, actor, actor, skill.duration,
            skillId: skill.id);
        return true;
      case SkillType.stun:
        final target = pickTarget(foes);
        if (target == null) return false;
        _hit(actor, target, actor.atk, skillId: skill.id);
        if (target.alive) {
          target.stunTurns += skill.duration;
          _emit(EventKind.stun, actor, target, skill.duration,
              skillId: skill.id);
        }
        return true;
      case SkillType.buffAtk:
        for (final c in allies) {
          if (!c.alive) continue;
          c.buffPct = skill.power;
          c.buffTurns = skill.duration;
          _emit(EventKind.buff, actor, c, skill.duration, skillId: skill.id);
        }
        return true;
      case SkillType.shield:
        for (final c in allies) {
          if (!c.alive) continue;
          c.shield = max(c.shield, (c.unit.baseStats.hp * skill.power).round());
          _emit(EventKind.shield, actor, c, c.shield, skillId: skill.id);
        }
        return true;
      case SkillType.reflect:
        actor.reflectTurns = skill.duration;
        actor.reflectPct = skill.power;
        _emit(EventKind.reflect, actor, actor, skill.duration,
            skillId: skill.id);
        return true;
      case SkillType.silence:
        Combatant? target;
        for (final c in foes) {
          if (!c.alive || c.silenceTurns > 0) continue;
          if (target == null ||
              c.unit.baseStats.atk > target.unit.baseStats.atk) {
            target = c;
          }
        }
        if (target == null) return false;
        target.silenceTurns = skill.duration;
        _emit(EventKind.silence, actor, target, skill.duration,
            skillId: skill.id);
        return true;
    }
  }
}

/// Runs a whole fight at once (heroes cast ultimates automatically).
BattleResult simulateBattle(
  List<Unit> heroes,
  List<Unit> enemies, {
  int maxRounds = 50,
}) {
  final battle = Battle(heroes, enemies, maxRounds: maxRounds)..auto = true;
  while (!battle.finished) {
    battle.step();
  }
  return battle.result;
}
