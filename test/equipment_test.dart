import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';
import 'package:theomyth/core/content.dart';
import 'package:theomyth/core/economy.dart';
import 'package:theomyth/core/equipment.dart';
import 'package:theomyth/core/models.dart';
import 'package:theomyth/core/player.dart';

void main() {
  final cfg =
      parseEquipment(File('assets/data/equipment.json').readAsStringSync());
  final eco = parseEconomy(File('assets/data/economy.json').readAsStringSync());
  final heroes = parseUnits(File('assets/data/heroes.json').readAsStringSync());

  Equipment item(int id, String slot, Rarity r, {int level = 0}) => Equipment(
      id: id, templateId: 'x', slot: slot, rarity: r, level: level);

  test('config has the 6 slots, a rule for each, and templates for each', () {
    expect(cfg.slots,
        ['weapon', 'armor', 'helm', 'boots', 'relic', 'ring']);
    for (final s in cfg.slots) {
      expect(cfg.slotRules.containsKey(s), isTrue, reason: s);
      expect(cfg.templates.any((t) => t.slot == s), isTrue, reason: s);
    }
    for (final r in Rarity.values) {
      expect(cfg.rarityMult.containsKey(r.name), isTrue);
      expect(cfg.maxUpgrade.containsKey(r.name), isTrue);
    }
  });

  test('every item name and slot has EN and EL strings', () {
    final en = parseStrings(File('assets/i18n/en.json').readAsStringSync());
    final el = parseStrings(File('assets/i18n/el.json').readAsStringSync());
    for (final t in cfg.templates) {
      expect(en.containsKey(t.nameKey), isTrue, reason: t.nameKey);
      expect(el.containsKey(t.nameKey), isTrue, reason: t.nameKey);
    }
    for (final s in cfg.slots) {
      expect(en.containsKey('slot.$s'), isTrue);
      expect(el.containsKey('slot.$s'), isTrue);
    }
  });

  test('higher rarity and higher level give a bigger bonus', () {
    final common = cfg.rawValue(item(1, 'weapon', Rarity.common));
    final legendary = cfg.rawValue(item(2, 'weapon', Rarity.legendary));
    final upgraded = cfg.rawValue(item(3, 'weapon', Rarity.common, level: 4));
    expect(legendary, greaterThan(common));
    expect(upgraded, greaterThan(common));
    expect(cfg.statOf(item(1, 'helm', Rarity.common)), BonusStat.def);
  });

  test('bonusOf sums percent stats and flat stats separately', () {
    final b = cfg.bonusOf([
      item(1, 'weapon', Rarity.common), // atk +6%
      item(2, 'relic', Rarity.common), // atk +4%
      item(3, 'armor', Rarity.common), // hp +8%
      item(4, 'helm', Rarity.common), // def +3
      item(5, 'boots', Rarity.common), // spd +2
    ]);
    expect(b.atkPct, closeTo(0.10, 1e-9));
    expect(b.hpPct, closeTo(0.08, 1e-9));
    expect(b.def, 3);
    expect(b.spd, 2);
    expect(cfg.bonusOf(const []).atkPct, 0);
  });

  test('unitWithEquipment applies level, stars and equipment', () {
    final h = heroes.first;
    final plain = unitWithEquipment(h, 1, eco);
    expect(plain.baseStats.hp, h.baseStats.hp);
    final geared = unitWithEquipment(h, 1, eco,
        bonus: const EquipBonus(hpPct: 0.5, atkPct: 0.1, def: 5, spd: 3));
    expect(geared.baseStats.hp, (h.baseStats.hp * 1.5).round());
    expect(geared.baseStats.atk, (h.baseStats.atk * 1.1).round());
    expect(geared.baseStats.def, h.baseStats.def + 5);
    expect(geared.baseStats.spd, h.baseStats.spd + 3);
    expect(geared.skills.length, h.skills.length);
  });

  group('upgrade and sell', () {
    test('upgrade spends gold, stops at the rarity cap', () {
      final p = PlayerState(
          gold: 100000, stars: {'heracles': 1}, inventory: [
        item(1, 'weapon', Rarity.common),
      ]);
      final cost0 = cfg.upgradeCost(p.itemById(1)!)!;
      expect(p.upgradeItem(1, cfg), isTrue);
      expect(p.gold, 100000 - cost0);
      expect(p.itemById(1)!.level, 1);
      expect(cfg.upgradeCost(p.itemById(1)!)! > cost0, isTrue);
      while (p.upgradeItem(1, cfg)) {}
      expect(p.itemById(1)!.level, cfg.maxUpgradeFor(Rarity.common));
      expect(cfg.upgradeCost(p.itemById(1)!), isNull);
    });

    test('upgrade needs enough gold', () {
      final p = PlayerState(gold: 1, inventory: [item(1, 'ring', Rarity.rare)]);
      expect(p.upgradeItem(1, cfg), isFalse);
      expect(p.gold, 1);
      expect(p.itemById(1)!.level, 0);
    });

    test('sell pays gold and refuses worn items', () {
      final p = PlayerState(
        stars: {'heracles': 1},
        inventory: [item(1, 'weapon', Rarity.epic), item(2, 'helm', Rarity.rare)],
      );
      expect(p.equip('heracles', 1, cfg), isTrue);
      expect(p.sellItem(1, cfg), isNull);
      final value = cfg.sellValue(item(2, 'helm', Rarity.rare));
      expect(p.sellItem(2, cfg), value);
      expect(p.gold, value);
      expect(p.itemById(2), isNull);
    });
  });

  group('equip', () {
    test('equip, replace in slot, unequip', () {
      final p = PlayerState(stars: {'heracles': 1}, inventory: [
        item(1, 'weapon', Rarity.common),
        item(2, 'weapon', Rarity.rare),
      ]);
      expect(p.equip('heracles', 1, cfg), isTrue);
      expect(p.wornInSlot('heracles', 'weapon')!.id, 1);
      expect(p.equip('heracles', 2, cfg), isTrue);
      expect(p.wornInSlot('heracles', 'weapon')!.id, 2);
      expect(p.wearerOf(1), isNull); // back in the bag, still owned
      expect(p.itemById(1), isNotNull);
      expect(p.unequip('heracles', 'weapon'), isTrue);
      expect(p.wornInSlot('heracles', 'weapon'), isNull);
      expect(p.unequip('heracles', 'weapon'), isFalse);
    });

    test('an item moves between heroes, not onto an unowned hero', () {
      final p = PlayerState(
          stars: {'heracles': 1, 'achilles': 1},
          inventory: [item(1, 'ring', Rarity.common)]);
      expect(p.equip('thor', 1, cfg), isFalse);
      expect(p.equip('heracles', 1, cfg), isTrue);
      expect(p.equip('achilles', 1, cfg), isTrue);
      expect(p.wearerOf(1), 'achilles');
      expect(p.wornInSlot('heracles', 'ring'), isNull);
      expect(p.equip('heracles', 99, cfg), isFalse);
    });

    test('bonusFor reads worn items only', () {
      final p = PlayerState(stars: {'heracles': 1}, inventory: [
        item(1, 'helm', Rarity.common),
        item(2, 'boots', Rarity.common),
      ]);
      p.equip('heracles', 1, cfg);
      expect(p.bonusFor('heracles', cfg).def, 3);
      expect(p.bonusFor('heracles', cfg).spd, 0);
    });
  });

  group('drops', () {
    test('rollItem respects minStage and picks a matching slot', () {
      final rnd = Random(1);
      for (var n = 0; n < 200; n++) {
        final it = cfg.rollItem(n + 1, 1, rnd)!;
        expect(it.rarity, Rarity.common); // only common unlocked at stage 1
        expect(cfg.templateById(it.templateId)!.slot, it.slot);
      }
      final high = [
        for (var n = 0; n < 2000; n++) cfg.rollItem(n, 100, rnd)!.rarity
      ];
      expect(high.contains(Rarity.legendary), isTrue);
    });

    test('rollItem is deterministic for a seed', () {
      final a = cfg.rollItem(1, 50, Random(7))!;
      final b = cfg.rollItem(1, 50, Random(7))!;
      expect(a.templateId, b.templateId);
      expect(a.rarity, b.rarity);
    });

    test('a boss win always drops, a loss never drops', () {
      final p = PlayerState.initial(eco);
      final boss = p.recordBattle(
          stage: 10,
          won: true,
          isBoss: true,
          economy: eco,
          equipment: cfg,
          rnd: Random(3));
      expect(boss.drops.length, cfg.bossDropCount);
      expect(p.inventory.length, cfg.bossDropCount);
      expect({for (final d in boss.drops) d.id}.length, cfg.bossDropCount);
      final lost = p.recordBattle(
          stage: 10,
          won: false,
          isBoss: false,
          economy: eco,
          equipment: cfg,
          rnd: Random(3));
      expect(lost.drops, isEmpty);
      expect(p.inventory.length, cfg.bossDropCount);
    });

    test('normal wins drop about dropChance of the time', () {
      final p = PlayerState.initial(eco);
      final rnd = Random(42);
      var dropped = 0;
      const runs = 1000;
      for (var n = 0; n < runs; n++) {
        final r = p.recordBattle(
            stage: 1,
            won: true,
            isBoss: false,
            economy: eco,
            equipment: cfg,
            rnd: rnd);
        dropped += r.drops.length;
        p.inventory.clear(); // keep room
      }
      expect(dropped / runs, closeTo(cfg.dropChance, 0.06));
    });

    test('a full inventory turns drops into gold', () {
      final full = EquipmentConfig(
        slots: cfg.slots,
        slotRules: cfg.slotRules,
        templates: cfg.templates,
        dropTable: cfg.dropTable,
        maxInventory: 1,
        bossDropCount: 2,
      );
      final p = PlayerState.initial(eco);
      final goldBefore = p.gold;
      final r = p.recordBattle(
          stage: 10,
          won: true,
          isBoss: true,
          economy: eco,
          equipment: full,
          rnd: Random(5));
      expect(p.inventory.length, 1);
      expect(r.drops.length, 1);
      expect(r.scrapGold, greaterThan(0));
      expect(p.gold, goldBefore + r.gold + r.scrapGold);
    });

    test('without an equipment config nothing drops (old behavior)', () {
      final p = PlayerState.initial(eco);
      final r =
          p.recordBattle(stage: 1, won: true, isBoss: false, economy: eco);
      expect(r.drops, isEmpty);
      expect(p.inventory, isEmpty);
    });
  });

  group('save', () {
    test('items, worn items and the id counter survive a round trip', () {
      final p = PlayerState(
        stars: {'heracles': 1},
        inventory: [
          item(4, 'weapon', Rarity.epic, level: 3),
          item(7, 'ring', Rarity.rare),
        ],
        nextItemId: 8,
      );
      p.equip('heracles', 4, cfg);
      final back = PlayerState.fromJson(p.toJson(), eco);
      expect(back.inventory.length, 2);
      expect(back.itemById(4)!.rarity, Rarity.epic);
      expect(back.itemById(4)!.level, 3);
      expect(back.wornInSlot('heracles', 'weapon')!.id, 4);
      expect(back.nextItemId, 8);
      expect(p.toJson()['v'], 3);
    });

    test('old saves have no equipment; bad references are dropped', () {
      final old = PlayerState.fromJson({'gold': 9}, eco);
      expect(old.inventory, isEmpty);
      expect(old.equipped, isEmpty);
      expect(old.nextItemId, 1);
      final bad = PlayerState.fromJson({
        'items': [
          {'id': 5, 't': 'x', 's': 'ring', 'r': 'rare', 'l': 1},
          {'broken': true},
        ],
        'equipped': {
          'heracles': {'ring': 5, 'weapon': 99}
        },
        'nextItemId': 1,
      }, eco);
      expect(bad.inventory.length, 1);
      expect(bad.wornInSlot('heracles', 'ring')!.id, 5);
      expect(bad.wornInSlot('heracles', 'weapon'), isNull);
      expect(bad.nextItemId, 6); // never reuses an id
    });
  });
}
