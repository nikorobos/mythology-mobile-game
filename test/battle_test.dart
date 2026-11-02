import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theomyth/core/battle.dart';
import 'package:theomyth/core/content.dart';
import 'package:theomyth/core/models.dart';
import 'package:theomyth/core/economy.dart';
import 'package:theomyth/core/format.dart';
import 'package:theomyth/core/player.dart';
import 'package:theomyth/core/stages.dart';

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

  test('endless stages: chapters, growth and bosses work', () {
    final cfg =
        parseStageConfig(File('assets/data/stages.json').readAsStringSync());
    final en = parseStrings(File('assets/i18n/en.json').readAsStringSync());
    final el = parseStrings(File('assets/i18n/el.json').readAsStringSync());
    for (final ch in cfg.chapters) {
      for (final id in [...ch.pool, ch.boss]) {
        expect(monsters.any((m) => m.id == id), isTrue, reason: id);
      }
      for (final key in [ch.titleKey, ch.introKey]) {
        expect(en.containsKey(key), isTrue, reason: key);
        expect(el.containsKey(key), isTrue, reason: key);
      }
    }
    final s1 = buildStage(1, monsters, cfg);
    final s7 = buildStage(7, monsters, cfg);
    expect(s1.length, 2);
    expect(s7.length, 5);
    final base = monsters.firstWhere((m) => m.id == s7.first.id);
    expect(s7.first.baseStats.hp > base.baseStats.hp, isTrue);
    expect(isBossStage(10, cfg), isTrue);
    expect(isBossStage(9, cfg), isFalse);
    final boss = buildStage(10, monsters, cfg);
    expect(boss.length, 5);
    expect(boss.first.id, cfg.chapters.first.boss);
    expect(boss.first.baseStats.hp > boss[1].baseStats.hp, isTrue);
    // Chapter 2 starts at stage 11 and loops back after the last chapter.
    expect(chapterAt(11, cfg).id, cfg.chapters[1].id);
    expect(chapterAt(1 + 10 * cfg.chapters.length, cfg).id, cfg.chapters[0].id);
    // Far-away stages must not crash or overflow.
    expect(buildStage(100000, monsters, cfg).length, 5);
    expect(() => buildStage(0, monsters, cfg), throwsArgumentError);
  });

  group('economy and player', () {
    final eco =
        parseEconomy(File('assets/data/economy.json').readAsStringSync());

    test('level multiplier and costs grow', () {
      expect(eco.statMult(1), 1.0);
      expect(eco.statMult(11), closeTo(2.2, 1e-9));
      expect(eco.levelUpCost(1), 100);
      expect(eco.levelUpCost(2) > eco.levelUpCost(1), isTrue);
      expect(eco.levelUpCost(100000) > 0, isTrue); // capped, no overflow
    });

    test('rewards: win > loss > 0, grow with stage', () {
      final win = eco.battleReward(1, won: true);
      final loss = eco.battleReward(1, won: false);
      expect(win, 50);
      expect(loss, 10);
      expect(eco.battleReward(10, won: true) > win, isTrue);
      expect(eco.battleReward(100000, won: true) > 0, isTrue);
    });

    test('unitAtLevel scales HP and ATK only', () {
      final h = heroes.first;
      final l11 = unitAtLevel(h, 11, eco);
      expect(l11.baseStats.hp, (h.baseStats.hp * 2.2).round());
      expect(l11.baseStats.atk, (h.baseStats.atk * 2.2).round());
      expect(l11.baseStats.def, h.baseStats.def);
      expect(l11.baseStats.spd, h.baseStats.spd);
      expect(l11.ultimate, isNotNull);
    });

    test('level up spends gold and needs enough gold', () {
      final p = PlayerState(gold: 150);
      expect(p.levelUp('heracles', eco), isTrue);
      expect(p.levelOf('heracles'), 2);
      expect(p.gold, 50);
      expect(p.levelUp('heracles', eco), isFalse);
      expect(p.levelOf('heracles'), 2);
    });

    test('battle result: gold always, stage only on a win', () {
      final p = PlayerState.initial(eco);
      expect(p.nextStage, 1);
      p.recordBattle(stage: 1, won: false, economy: eco);
      expect(p.nextStage, 1);
      expect(p.gold, eco.startGold + 10);
      p.recordBattle(stage: 1, won: true, economy: eco);
      expect(p.nextStage, 2);
      p.recordBattle(stage: 1, won: true, economy: eco); // replay older stage
      expect(p.highestStageCleared, 1);
    });

    test('save JSON round trip, missing keys fall back', () {
      final p = PlayerState(gold: 7, heroLevels: {'thor': 4}, highestStageCleared: 3);
      final back = PlayerState.fromJson(p.toJson());
      expect(back.gold, 7);
      expect(back.levelOf('thor'), 4);
      expect(back.highestStageCleared, 3);
      final empty = PlayerState.fromJson({});
      expect(empty.gold, 0);
      expect(empty.levelOf('thor'), 1);
    });
  });

  test('formatNumber abbreviates', () {
    expect(formatNumber(999), '999');
    expect(formatNumber(1500), '1.50K');
    expect(formatNumber(12345), '12.3K');
    expect(formatNumber(2500000), '2.50M');
  });

  test('scaled copies stats', () {
    final scaled = monsters.first.scaled(hp: 2.0, atk: 0.5);
    expect(scaled.baseStats.hp, monsters.first.baseStats.hp * 2);
    expect(scaled.baseStats.atk, (monsters.first.baseStats.atk * 0.5).round());
  });

  test('stronger side wins', () {
    final r = simulateBattle(heroes, [monsters[1]]);
    expect(r.winner, Side.heroes);
  });
}
