// Pure Dart player progress. Saved as JSON (see lib/state).

import 'dart:math' show Random;

import 'economy.dart';
import 'models.dart';

class BattleReward {
  const BattleReward({required this.gold, this.gems = 0});

  final int gold;
  final int gems;
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
  })  : heroLevels = heroLevels ?? {},
        stars = stars ?? {},
        shards = shards ?? {};

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
  }) {
    final goldReward = economy.battleReward(stage, won: won);
    gold += goldReward;
    var gemReward = 0;
    if (won && stage > highestStageCleared) {
      highestStageCleared = stage;
      gemReward = isBoss ? economy.bossClearGems : economy.stageClearGems;
      gems += gemReward;
    }
    return BattleReward(gold: goldReward, gems: gemReward);
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

  // ---- save ----

  Map<String, dynamic> toJson() => {
        'v': 2,
        'gold': gold,
        'gems': gems,
        'heroLevels': heroLevels,
        'stars': stars,
        'shards': shards,
        'pity': pity,
        'highestStageCleared': highestStageCleared,
      };

  /// Older saves (v1) had no stars/gems: they get the starter heroes and
  /// starting gems so nobody loses progress.
  factory PlayerState.fromJson(Map<String, dynamic> j, Economy e) {
    Map<String, int> ints(Object? m) => {
          for (final entry in ((m as Map?) ?? const {}).entries)
            entry.key as String: entry.value as int
        };
    return PlayerState(
      gold: (j['gold'] as int?) ?? 0,
      gems: (j['gems'] as int?) ?? e.startGems,
      heroLevels: ints(j['heroLevels']),
      stars: j['stars'] == null
          ? {for (final id in e.starterHeroes) id: 1}
          : ints(j['stars']),
      shards: ints(j['shards']),
      pity: (j['pity'] as int?) ?? 0,
      highestStageCleared: (j['highestStageCleared'] as int?) ?? 0,
    );
  }
}
