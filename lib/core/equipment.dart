// Pure Dart equipment: items, slots, upgrades, drops, stat bonuses.
// All numbers come from assets/data/equipment.json (PLACEHOLDERS).

import 'dart:math' show Random, max, min, pow;

import 'economy.dart';
import 'models.dart';

/// Which hero stat a slot improves.
enum BonusStat { hp, atk, def, spd }

BonusStat _bonusStat(String name) => BonusStat.values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw FormatException('Unknown bonus stat "$name"'),
    );

/// How one slot behaves: [stat] it raises and the [base] value of a common
/// item at upgrade level 0. For hp/atk the base is a fraction (0.05 = +5%),
/// for def/spd it is a flat number.
class SlotRule {
  const SlotRule({required this.stat, required this.base});

  final BonusStat stat;
  final double base;
}

/// A kind of item (name + slot + mythology tag). Instances are [Equipment].
class ItemTemplate {
  const ItemTemplate({
    required this.id,
    required this.slot,
    required this.nameKey,
    required this.mythology,
  });

  final String id;
  final String slot;
  final String nameKey;
  final String mythology;

  factory ItemTemplate.fromJson(Map<String, dynamic> j) => ItemTemplate(
        id: j['id'] as String,
        slot: j['slot'] as String,
        nameKey: j['nameKey'] as String,
        mythology: (j['mythology'] as String?) ?? '',
      );
}

/// One item the player owns. [id] is unique inside a save.
class Equipment {
  const Equipment({
    required this.id,
    required this.templateId,
    required this.slot,
    required this.rarity,
    this.level = 0,
  });

  final int id;
  final String templateId;
  final String slot;
  final Rarity rarity;

  /// Upgrade level (0 = not upgraded).
  final int level;

  Equipment withLevel(int newLevel) => Equipment(
        id: id,
        templateId: templateId,
        slot: slot,
        rarity: rarity,
        level: newLevel,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        't': templateId,
        's': slot,
        'r': rarity.name,
        'l': level,
      };

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        id: j['id'] as int,
        templateId: j['t'] as String,
        slot: j['s'] as String,
        rarity: Rarity.values.firstWhere((r) => r.name == j['r'] as String),
        level: (j['l'] as int?) ?? 0,
      );
}

/// Summed bonuses of a hero's equipped items.
class EquipBonus {
  const EquipBonus({
    this.hpPct = 0,
    this.atkPct = 0,
    this.def = 0,
    this.spd = 0,
  });

  /// Fractions: 0.1 = +10%.
  final double hpPct;
  final double atkPct;
  final int def;
  final int spd;

  static const none = EquipBonus();
}

/// A rarity row in the drop table.
class DropRow {
  const DropRow({required this.rarity, required this.weight, required this.minStage});

  final Rarity rarity;
  final int weight;
  final int minStage;
}

class EquipmentConfig {
  const EquipmentConfig({
    required this.slots,
    required this.slotRules,
    required this.templates,
    this.rarityMult = const {
      'common': 1.0,
      'rare': 1.6,
      'epic': 2.5,
      'legendary': 4.0,
    },
    this.maxUpgrade = const {
      'common': 5,
      'rare': 8,
      'epic': 12,
      'legendary': 15,
    },
    this.upgradeStatGrowth = 0.15,
    this.upgradeCostBase = 50,
    this.upgradeCostGrowth = 1.25,
    this.sellGoldBase = 10,
    this.maxInventory = 200,
    this.dropChance = 0.35,
    this.bossDropCount = 2,
    this.bossEpicBoost = 3,
    this.dropTable = const [],
  });

  /// Slot ids in display order.
  final List<String> slots;
  final Map<String, SlotRule> slotRules;
  final List<ItemTemplate> templates;

  /// Rarity name -> stat multiplier (also scales upgrade and sell cost).
  final Map<String, double> rarityMult;

  /// Rarity name -> highest upgrade level.
  final Map<String, int> maxUpgrade;

  /// Each upgrade level adds this fraction of the level-0 value.
  final double upgradeStatGrowth;
  final double upgradeCostBase;
  final double upgradeCostGrowth;
  final double sellGoldBase;
  final int maxInventory;

  /// Chance (0..1) that a won non-boss battle drops one item.
  final double dropChance;

  /// A boss win always drops this many items.
  final int bossDropCount;

  /// Weight multiplier for epic and legendary on boss drops.
  final int bossEpicBoost;
  final List<DropRow> dropTable;

  factory EquipmentConfig.fromJson(Map<String, dynamic> j) {
    const base = EquipmentConfig(slots: [], slotRules: {}, templates: []);
    final slotRules = <String, SlotRule>{
      for (final e in (j['slotRules'] as Map).entries)
        e.key as String: SlotRule(
          stat: _bonusStat((e.value as Map)['stat'] as String),
          base: ((e.value as Map)['base'] as num).toDouble(),
        )
    };
    final slots = List<String>.from(j['slots'] as List);
    for (final s in slots) {
      if (!slotRules.containsKey(s)) {
        throw FormatException('Slot "$s" has no rule');
      }
    }
    return EquipmentConfig(
      slots: slots,
      slotRules: slotRules,
      templates: [
        for (final t in j['templates'] as List)
          ItemTemplate.fromJson(t as Map<String, dynamic>)
      ],
      rarityMult: j['rarityMult'] == null
          ? base.rarityMult
          : {
              for (final e in (j['rarityMult'] as Map).entries)
                e.key as String: (e.value as num).toDouble()
            },
      maxUpgrade: j['maxUpgrade'] == null
          ? base.maxUpgrade
          : {
              for (final e in (j['maxUpgrade'] as Map).entries)
                e.key as String: e.value as int
            },
      upgradeStatGrowth:
          (j['upgradeStatGrowth'] as num?)?.toDouble() ?? base.upgradeStatGrowth,
      upgradeCostBase:
          (j['upgradeCostBase'] as num?)?.toDouble() ?? base.upgradeCostBase,
      upgradeCostGrowth:
          (j['upgradeCostGrowth'] as num?)?.toDouble() ?? base.upgradeCostGrowth,
      sellGoldBase:
          (j['sellGoldBase'] as num?)?.toDouble() ?? base.sellGoldBase,
      maxInventory: (j['maxInventory'] as int?) ?? base.maxInventory,
      dropChance: (j['dropChance'] as num?)?.toDouble() ?? base.dropChance,
      bossDropCount: (j['bossDropCount'] as int?) ?? base.bossDropCount,
      bossEpicBoost: (j['bossEpicBoost'] as int?) ?? base.bossEpicBoost,
      dropTable: [
        for (final r in (j['dropTable'] as List? ?? const []))
          DropRow(
            rarity: Rarity.values
                .firstWhere((x) => x.name == (r as Map)['rarity'] as String),
            weight: r['weight'] as int,
            minStage: (r['minStage'] as int?) ?? 1,
          )
      ],
    );
  }

  double _mult(Rarity r) => rarityMult[r.name] ?? 1.0;

  ItemTemplate? templateById(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Highest upgrade level for an item of [r].
  int maxUpgradeFor(Rarity r) => maxUpgrade[r.name] ?? 0;

  /// Raw (unrounded) bonus of [item]: fraction for hp/atk, flat for def/spd.
  double rawValue(Equipment item) {
    final rule = slotRules[item.slot];
    if (rule == null) return 0;
    return rule.base * _mult(item.rarity) * (1 + upgradeStatGrowth * item.level);
  }

  /// Stat an item raises (null if its slot is unknown).
  BonusStat? statOf(Equipment item) => slotRules[item.slot]?.stat;

  /// Gold to upgrade [item] from its level to level + 1 (null at max).
  int? upgradeCost(Equipment item) {
    if (item.level >= maxUpgradeFor(item.rarity)) return null;
    final c = upgradeCostBase *
        _mult(item.rarity) *
        pow(upgradeCostGrowth, item.level);
    return min(c, 1e12).round();
  }

  /// Gold received for selling [item] (also the value of a dropped item
  /// that does not fit in a full inventory).
  int sellValue(Equipment item) =>
      max(1, (sellGoldBase * _mult(item.rarity) * (1 + item.level)).round());

  /// Sums the bonuses of [items] (the ones a hero wears).
  EquipBonus bonusOf(Iterable<Equipment> items) {
    var hp = 0.0, atk = 0.0, def = 0.0, spd = 0.0;
    for (final item in items) {
      final stat = statOf(item);
      if (stat == null) continue;
      final v = rawValue(item);
      switch (stat) {
        case BonusStat.hp:
          hp += v;
        case BonusStat.atk:
          atk += v;
        case BonusStat.def:
          def += v;
        case BonusStat.spd:
          spd += v;
      }
    }
    return EquipBonus(
      hpPct: hp,
      atkPct: atk,
      def: def.round(),
      spd: spd.round(),
    );
  }

  /// Rolls a random item for a win on [stage]. [id] is the new item id.
  /// Returns null if there is nothing to drop (empty tables).
  Equipment? rollItem(int id, int stage, Random rnd, {bool boss = false}) {
    if (templates.isEmpty) return null;
    final rows = [
      for (final r in dropTable)
        if (stage >= r.minStage) r
    ];
    if (rows.isEmpty) return null;
    int weightOf(DropRow r) {
      final boost = boss && r.rarity.index >= Rarity.epic.index
          ? max(1, bossEpicBoost)
          : 1;
      return r.weight * boost;
    }

    final total = rows.fold<int>(0, (a, r) => a + weightOf(r));
    if (total <= 0) return null;
    var roll = rnd.nextInt(total);
    var rarity = rows.first.rarity;
    for (final r in rows) {
      final w = weightOf(r);
      if (roll < w) {
        rarity = r.rarity;
        break;
      }
      roll -= w;
    }
    final t = templates[rnd.nextInt(templates.length)];
    return Equipment(
      id: id,
      templateId: t.id,
      slot: t.slot,
      rarity: rarity,
    );
  }
}

/// A hero ready for battle: level, stars and equipment applied.
Unit unitWithEquipment(
  Unit u,
  int level,
  Economy e, {
  int stars = 1,
  EquipBonus bonus = EquipBonus.none,
}) {
  final base = unitAtLevel(u, level, e, stars: stars);
  return base.withBonus(
    hpMult: 1 + bonus.hpPct,
    atkMult: 1 + bonus.atkPct,
    def: bonus.def,
    spd: bonus.spd,
  );
}
