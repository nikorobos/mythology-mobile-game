import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theomyth/core/battle.dart';
import 'package:theomyth/core/content.dart';
import 'package:theomyth/core/models.dart';

void main() {
  final heroes = parseUnits(File('assets/data/heroes.json').readAsStringSync());
  final monsters =
      parseUnits(File('assets/data/monsters.json').readAsStringSync());

  test('content parses into units', () {
    expect(heroes.length, 3);
    expect(monsters.every((m) => m.ai), isTrue);
    expect(heroes.first.role, Role.tank);
  });

  test('every nameKey exists in both languages', () {
    final en = parseStrings(File('assets/i18n/en.json').readAsStringSync());
    final el = parseStrings(File('assets/i18n/el.json').readAsStringSync());
    for (final u in [...heroes, ...monsters]) {
      expect(en.containsKey(u.nameKey), isTrue, reason: u.nameKey);
      expect(el.containsKey(u.nameKey), isTrue, reason: u.nameKey);
      for (final s in u.skills) {
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

  Unit mk(String id, Range range, int hp, int atk, int spd, List<Skill> skills) =>
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

  test('stronger side wins', () {
    final r = simulateBattle(heroes, [monsters[1]]);
    expect(r.winner, Side.heroes);
  });
}
