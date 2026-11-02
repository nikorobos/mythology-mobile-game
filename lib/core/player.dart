// Pure Dart player progress. Saved as JSON (see lib/state).

import 'dart:math' show Random, max, min;

import 'economy.dart';
import 'equipment.dart';
import 'models.dart';

class BattleReward {
  const BattleReward({
    required this.gold,
    this.gems = 0,
    this.drops = const [],
    this.scrapGold = 0,
  });

  final int gold;
  final int gems;

  /// Items added to the inventory by this battle.
  final List<Equipment> drops;

  /// Gold from drops that did not fit in a full inventory (already added
  /// to the player's gold, not included in [gold]).
  final int scrapGold;
}

class SummonResult {
  const SummonResult({
    required this.heroId,
    required this.isNew,
    required this.shardsGained,
  });

  final String heroId;
  final bool isNew;
  final int shardsGained;
}

class PlayerState {
  PlayerState({
    this.gold = 0,
    this.gems = 0,
    Map<String, int>? heroLevels,
    Map<String, int>? stars,
    Map<String, int>? shards,
    this.pity = 0,
    this.highestStageCleared = 0,
    this.lastCollectMs,
    List<Equipment>? inventory,
    Map<String, Map<String, int>>? equipped,
    this.nextItemId = 1,
  })  : heroLevels = heroLevels ?? {},
        stars = stars ?? {},
        shards = shards ?? {},
        inventory = inventory ?? [],
        equipped = equipped ?? {};

  factory PlayerState.initial(Economy e) => PlayerState(
        gold: e.startGold,
        gems: e.startGems,
        stars: {for (final id in e.starterHeroes) id: 1},
      );

  int gold;
  int gems;
  final Map<String, int> heroLevels;

  /// Owned heroes only: hero id -> stars (1..maxStars).
  final Map<String, int> stars;
  final Map<String, int> shards;

  /// Pulls since the last epic (for the guarantee).
  int pity;
  int highestStageCleared;

  /// When idle gold was last collected (ms since epoch). Null = not started.
  int? lastCollectMs;

  /// Every item the player owns (worn or not).
  final List<Equipment> inventory;

  /// Hero id -> slot -> item id of the worn item.
  final Map<String, Map<String, int>> equipped;

  /// Id given to the next item that drops.
  int nextItemId;

  bool owns(String heroId) => stars.containsKey(heroId);
  int starsOf(String heroId) => stars[heroId] ?? 0;
  int shardsOf(String heroId) => shards[heroId] ?? 0;
  int levelOf(String heroId) => heroLevels[heroId] ?? 1;

  /// Highest stage the player may attempt.
  int get nextStage => highestStageCleared + 1;

  // ---- levels ----

  bool canLevelUp(String heroId, Economy e) =>
      owns(heroId) &&
      levelOf(heroId) < e.maxLevel &&
      gold >= e.levelUpCost(levelOf(heroId));

  bool levelUp(String heroId, Economy e) {
    if (!canLevelUp(heroId, e)) return false;
    gold -= e.levelUpCost(levelOf(heroId));
    heroLevels[heroId] = levelOf(heroId) + 1;
    return true;
  }

  // ---- stars ----

  bool canStarUp(String heroId, Economy e) {
    if (!owns(heroId)) return false;
    final cost = e.starUpCost(starsOf(heroId));
    return cost != null && shardsOf(heroId) >= cost;
  }

  bool starUp(String heroId, Economy e) {
    if (!canStarUp(heroId, e)) return false;
    shards[heroId] = shardsOf(heroId) - e.starUpCost(starsOf(heroId))!;
    stars[heroId] = starsOf(heroId) + 1;
    return true;
  }

  // ---- battles ----

  /// Applies a finished battle. Gems are paid for the first clear of a stage.
  BattleReward recordBattle({
    required int stage,
    required bool won,
    required bool isBoss,
    required Economy economy,
    EquipmentConfig? equipment,
    Random? rnd,
  }) {
    final goldReward = economy.battleReward(stage, won: won);
    gold += goldReward;
    var gemReward = 0;
    if (won && stage > highestStageCleared) {
      highestStageCleared = stage;
      gemReward = isBoss ? economy.bossClearGems : economy.stageClearGems;
      gems += gemReward;
    }
    final drops = <Equipment>[];
    var scrap = 0;
    if (won && equipment != null && rnd != null) {
      final count = isBoss
          ? equipment.bossDropCount
          : (rnd.nextDouble() < equipment.dropChance ? 1 : 0);
      for (var n = 0; n < count; n++) {
        final item = equipment.rollItem(nextItemId, stage, rnd, boss: isBoss);
        if (item == null) continue;
        nextItemId++;
        if (inventory.length >= equipment.maxInventory) {
          // Full inventory: the item turns into gold.
          scrap += equipment.sellValue(item);
        } else {
          inventory.add(item);
          drops.add(item);
        }
      }
      gold += scrap;
    }
    return BattleReward(
      gold: goldReward,
      gems: gemReward,
      drops: drops,
      scrapGold: scrap,
    );
  }

  // ---- equipment ----

  Equipment? itemById(int id) {
    for (final i in inventory) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Hero wearing item [itemId], or null.
  String? wearerOf(int itemId) {
    for (final e in equipped.entries) {
      if (e.value.containsValue(itemId)) return e.key;
    }
    return null;
  }

  /// Items [heroId] wears.
  List<Equipment> wornBy(String heroId) => [
        for (final id in (equipped[heroId] ?? const <String, int>{}).values)
          if (itemById(id) != null) itemById(id)!
      ];

  /// Item worn in [slot] by [heroId], or null.
  Equipment? wornInSlot(String heroId, String slot) {
    final id = equipped[heroId]?[slot];
    return id == null ? null : itemById(id);
  }

  EquipBonus bonusFor(String heroId, EquipmentConfig cfg) =>
      cfg.bonusOf(wornBy(heroId));

  /// Puts item [itemId] on [heroId]. An item worn by another hero moves over;
  /// the item that was in that slot goes back to the inventory.
  bool equip(String heroId, int itemId, EquipmentConfig cfg) {
    final item = itemById(itemId);
    if (item == null || !owns(heroId)) return false;
    if (!cfg.slots.contains(item.slot)) return false;
    final other = wearerOf(itemId);
    if (other != null) equipped[other]?.remove(item.slot);
    (equipped[heroId] ??= {})[item.slot] = itemId;
    return true;
  }

  bool unequip(String heroId, String slot) =>
      equipped[heroId]?.remove(slot) != null;

  /// Spends gold to raise an item one level.
  bool upgradeItem(int itemId, EquipmentConfig cfg) {
    final item = itemById(itemId);
    if (item == null) return false;
    final cost = cfg.upgradeCost(item);
    if (cost == null || gold < cost) return false;
    gold -= cost;
    final index = inventory.indexWhere((i) => i.id == itemId);
    inventory[index] = item.withLevel(item.level + 1);
    return true;
  }

  /// Sells an item that nobody wears. Returns the gold, or null if refused.
  int? sellItem(int itemId, EquipmentConfig cfg) {
    final item = itemById(itemId);
    if (item == null || wearerOf(itemId) != null) return null;
    final value = cfg.sellValue(item);
    inventory.removeWhere((i) => i.id == itemId);
    gold += value;
    return value;
  }

  // ---- summon ----

  /// Pulls [count] heroes. Returns null if there are not enough gems.
  /// Pass a seeded [rnd] in tests.
  List<SummonResult>? summon(
    int count,
    List<Unit> heroes,
    Economy e,
    Random rnd,
  ) {
    final cost = e.summonCost(count);
    if (gems < cost || heroes.isEmpty) return null;
    gems -= cost;
    final results = <SummonResult>[];
    for (var n = 0; n < count; n++) {
      final forceEpic = pity >= e.pityEpic - 1;
      final rarity = forceEpic ? 'epic' : _rollRarity(e.rarityWeights, rnd);
      var pool = heroes.where((h) => h.rarity.name == rarity).toList();
      if (pool.isEmpty) pool = heroes;
      final hero = pool[rnd.nextInt(pool.length)];
      pity = hero.rarity.index >= Rarity.epic.index ? 0 : pity + 1;
      if (owns(hero.id)) {
        shards[hero.id] = shardsOf(hero.id) + e.dupShards;
        results.add(SummonResult(
            heroId: hero.id, isNew: false, shardsGained: e.dupShards));
      } else {
        stars[hero.id] = 1;
        results.add(
            SummonResult(heroId: hero.id, isNew: true, shardsGained: 0));
      }
    }
    return results;
  }

  static String _rollRarity(Map<String, int> weights, Random rnd) {
    final total = weights.values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return 'rare';
    var r = rnd.nextInt(total);
    for (final entry in weights.entries) {
      if (r < entry.value) return entry.key;
      r -= entry.value;
    }
    return weights.keys.first;
  }

  // ---- idle rewards ----

  double _idleRate(Economy e) =>
      e.idleGoldPerMinute(max(1, highestStageCleared));

  /// Most idle gold that can pile up while away.
  int maxIdleGold(Economy e) => (e.maxIdleMinutes * _idleRate(e)).floor();

  /// Idle gold waiting at [nowMs]. A clock set backwards gives 0.
  int idleGoldPending(int nowMs, Economy e) {
    final last = lastCollectMs;
    if (last == null || nowMs <= last) return 0;
    final minutes = min((nowMs - last) / 60000.0, e.maxIdleMinutes.toDouble());
    return (minutes * _idleRate(e)).floor();
  }

  /// Adds the waiting idle gold (times [multiplier]) and restarts the timer.
  int collectIdle(int nowMs, Economy e, {int multiplier = 1}) {
    final amount = idleGoldPending(nowMs, e) * multiplier;
    gold += amount;
    lastCollectMs = nowMs;
    return amount;
  }

  // ---- save ----

  Map<String, dynamic> toJson() => {
        'v': 3,
        'gold': gold,
        'gems': gems,
        'heroLevels': heroLevels,
        'stars': stars,
        'shards': shards,
        'pity': pity,
        'highestStageCleared': highestStageCleared,
        'lastCollectMs': lastCollectMs,
        'items': [for (final i in inventory) i.toJson()],
        'equipped': equipped,
        'nextItemId': nextItemId,
      };

  /// Older saves (v1) had no stars/gems: they get the starter heroes and
  /// starting gems so nobody loses progress.
  factory PlayerState.fromJson(Map<String, dynamic> j, Economy e) {
    Map<String, int> ints(Object? m) => {
          for (final entry in ((m as Map?) ?? const {}).entries)
            entry.key as String: entry.value as int
        };
    // v3 added equipment; older saves simply have none.
    final items = <Equipment>[];
    for (final raw in (j['items'] as List?) ?? const []) {
      try {
        items.add(Equipment.fromJson(raw as Map<String, dynamic>));
      } catch (_) {
        // Skip an unreadable item instead of losing the whole save.
      }
    }
    final ids = {for (final i in items) i.id};
    final worn = <String, Map<String, int>>{};
    for (final entry in ((j['equipped'] as Map?) ?? const {}).entries) {
      final slots = <String, int>{};
      for (final s in (entry.value as Map).entries) {
        final id = s.value as int;
        if (ids.contains(id)) slots[s.key as String] = id;
      }
      worn[entry.key as String] = slots;
    }
    var nextId = (j['nextItemId'] as int?) ?? 1;
    for (final id in ids) {
      if (id >= nextId) nextId = id + 1;
    }
    return PlayerState(
      inventory: items,
      equipped: worn,
      nextItemId: nextId,
      gold: (j['gold'] as int?) ?? 0,
      gems: (j['gems'] as int?) ?? e.startGems,
      heroLevels: ints(j['heroLevels']),
      stars: j['stars'] == null
          ? {for (final id in e.starterHeroes) id: 1}
          : ints(j['stars']),
      shards: ints(j['shards']),
      pity: (j['pity'] as int?) ?? 0,
      highestStageCleared: (j['highestStageCleared'] as int?) ?? 0,
      lastCollectMs: j['lastCollectMs'] as int?,
    );
  }
}
