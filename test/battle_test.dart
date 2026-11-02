import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theomyth/core/battle.dart';
import 'package:theomyth/core/content.dart';
import 'package:theomyth/core/models.dart';
import 'package:theomyth/game_content.dart';

void main() {
  final heroes = parseUnits(File('assets/data/heroes.json').readAsStringSync());
  final monsters =
      parseUnits(File('assets/data/monsters.json').readAsStringSync());

  test('content parses into units', () {
    expect(heroes.length, 9);
    expect(monsters.length, 6);
    expect(monsters.every((m) => m.ai), isTrue);
    expect(heroes.first.role, Role.tank);
  });

  test('every nameKey exists in both languages', () {
    final en = parseStrings(File('assets/i18n/en.json').readAsStringSync());
    final el = parseStrings(File('assets/i18n/el.json').readAsStringSync());
    for (final u in [...heroes, ...monsters]) {
      expect(en.containsKey(u.nameKey), isTrue, reason: u.nameKey);
      expect(el.containsKey(u.nameKey), isTrue, reason: u.nameKey);
      for (final s in [...u.skills, if (u.ultimate != null) u.ultimate!]) {
        expect(en.containsKey(s.nameKey), isTrue, reason: s.nameKey);
        expect(el.containsKey(s.nameKey), isTrue, reason: s.nameKey);
      }
    }
  });

  test('damage is at least 1', () {
    expect(calcDamage(1, 1000), 1);
    expect(calcDamage(100, 40), 80);
  });

  test('battle is deterministic and ends', () {
    final a = simulateBattle(heroes, monsters);
    final b = simulateBattle(heroes, monsters);
    expect(a.log, b.log);
    expect(a.winner, isNotNull);
  });

  test('events match the log and end with the loser at 0 hp', () {
    final r = simulateBattle(heroes, monsters);
    expect(r.events.length, r.log.length);
    expect(r.events.last.targetHpAfter, 0);
  });

  test('every role has a label in both languages', () {
    final en = parseStrings(File('assets/i18n/en.json').readAsStringSync());
    final el = parseStrings(File('assets/i18n/el.json').readAsStringSync());
    for (final r in Role.values) {
      expect(en.containsKey('role.${r.name}'), isTrue);
      expect(el.containsKey('role.${r.name}'), isTrue);
    }
  });

  test('prototype fight uses taunt and stun skills', () {
    final r = simulateBattle(heroes, monsters);
    expect(r.events.any((e) => e.kind == EventKind.taunt), isTrue);
    expect(r.events.any((e) => e.kind == EventKind.stun), isTrue);
    expect(r.events.any((e) => e.kind == EventKind.skip), isTrue);
  });

  Unit mk(String id, Range range, int hp, int atk, int spd, List<Skill> skills,
          {Skill? ultimate}) =>
      Unit(
        id: id,
        nameKey: id,
        mythology: 'test',
        tags: const [],
        role: Role.dps,
        range: range,
        rarity: Rarity.common,
        baseStats: Stats(hp: hp, atk: atk, def: 0, spd: spd),
        skills: skills,
        ultimate: ultimate,
      );

  test('heal restores missing HP only', () {
    final healer = mk('healer', Range.ranged, 100, 1, 100, const [
      Skill(
          id: 'h',
          nameKey: 'h',
          descKey: 'h',
          type: SkillType.heal,
          power: 0.25,
          cooldown: 3)
    ]);
    final tank = mk('tank', Range.melee, 100, 1, 50, const []);
    final foe = mk('foe', Range.melee, 1000, 10, 1, const []);
    final r = simulateBattle([healer, tank], [foe], maxRounds: 2);
    final heals = r.events.where((e) => e.kind == EventKind.heal).toList();
    expect(heals.length, 1);
    expect(heals.first.amount, 10);
    expect(heals.first.targetHpAfter, 100);
  });

  test('stun makes the target skip its next turn', () {
    final stunner = mk('stunner', Range.melee, 1000, 10, 100, const [
      Skill(
          id: 's',
          nameKey: 's',
          descKey: 's',
          type: SkillType.stun,
          duration: 1,
          cooldown: 3)
    ]);
    final foe = mk('foe', Range.melee, 1000, 10, 1, const []);
    final r = simulateBattle([stunner], [foe], maxRounds: 1);
    final skip = r.events.where((e) => e.kind == EventKind.skip).toList();
    expect(skip.length, 1);
    expect(skip.first.actorIndex, 1);
  });

  group('ultimate', () {
    const ult = Skill(
        id: 'u',
        nameKey: 'u',
        descKey: 'u',
        type: SkillType.damageAll,
        power: 1.0);
    Unit hero() => mk('hero', Range.melee, 100000, 1, 100, const [],
        ultimate: ult);
    Unit foe() => mk('foe', Range.melee, 100000, 1, 1, const []);

    Battle run(void Function(Battle) setup) {
      final b = Battle([hero()], [foe()], maxRounds: 6);
      setup(b);
      while (!b.finished) {
        b.step();
      }
      return b;
    }

    test('AUTO casts when energy is full (round 4)', () {
      final b = run((b) => b.auto = true);
      final casts = b.events.where((e) => e.skillId == 'u').toList();
      expect(casts, isNotEmpty);
      expect(casts.first.round, 4);
    });

    test('manual mode does not cast until queued', () {
      final b = run((b) => b.auto = false);
      expect(b.events.any((e) => e.skillId == 'u'), isFalse);
    });

    test('queued ultimate casts once energy is full', () {
      final b = run((b) {
        b.auto = false;
        b.queueUltimate(0);
      });
      final casts = b.events.where((e) => e.skillId == 'u').toList();
      expect(casts.first.round, 4);
    });
  });

  test('shield absorbs damage', () {
    final shielder = mk('shielder', Range.melee, 100, 1, 100, const [
      Skill(
          id: 'sh',
          nameKey: 'sh',
          descKey: 'sh',
          type: SkillType.shield,
          power: 0.5)
    ]);
    final foe = mk('foe', Range.melee, 1000, 30, 1, const []);
    final r = simulateBattle([shielder], [foe], maxRounds: 1);
    final foeHit = r.events
        .where((e) => e.kind == EventKind.attack && e.actorIndex == 1)
        .first;
    expect(foeHit.amount, 0);
    expect(foeHit.targetHpAfter, 100);
  });

  test('reflect sends damage back', () {
    final tank = mk('tank', Range.melee, 1000, 1, 100, const [
      Skill(
          id: 'rf',
          nameKey: 'rf',
          descKey: 'rf',
          type: SkillType.reflect,
          power: 0.5,
          duration: 2)
    ]);
    final foe = mk('foe', Range.melee, 1000, 40, 1, const []);
    final r = simulateBattle([tank], [foe], maxRounds: 1);
    final last = r.events.last;
    expect(last.kind, EventKind.attack);
    expect(last.actorIndex, 0);
    expect(last.targetIndex, 1);
    expect(last.amount, 20);
    expect(last.targetHpAfter, 980);
  });

  test('silence stops skills but not basic attacks', () {
    final silencer = mk('silencer', Range.melee, 100000, 1, 100, const [
      Skill(
          id: 'si',
          nameKey: 'si',
          descKey: 'si',
          type: SkillType.silence,
          duration: 2)
    ]);
    final foe = mk('foe', Range.melee, 1000, 10, 1, const [
      Skill(
          id: 'tri',
          nameKey: 'tri',
          descKey: 'tri',
          type: SkillType.damageMulti,
          hits: 3)
    ]);
    final r = simulateBattle([silencer], [foe], maxRounds: 1);
    final foeAttacks = r.events
        .where((e) => e.kind == EventKind.attack && e.actorIndex == 1)
        .toList();
    expect(foeAttacks.length, 1);
    expect(foeAttacks.first.skillId, isNull);
  });

  test('stages reference existing monsters and scale them', () {
    final stages =
        parseStages(File('assets/data/stages.json').readAsStringSync());
    expect(stages, isNotEmpty);
    for (final st in stages) {
      final enemies = enemiesFor(monsters, st);
      expect(enemies.length, st.enemies.length);
    }
    final scaled = monsters.first.scaled(hp: 2.0, atk: 0.5);
    expect(scaled.baseStats.hp, monsters.first.baseStats.hp * 2);
    expect(scaled.baseStats.atk, (monsters.first.baseStats.atk * 0.5).round());
  });

  test('stronger side wins', () {
    final r = simulateBattle(heroes, [monsters[1]]);
    expect(r.winner, Side.heroes);
  });
}
