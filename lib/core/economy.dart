// Pure Dart. Placeholder economy numbers come from assets/data/economy.json.

import 'dart:math' show min, pow;

import 'models.dart';

class Economy {
  const Economy({
    this.startGold = 500,
    this.startGems = 300,
    this.starterHeroes = const ['heracles', 'achilles', 'asclepius'],
    this.maxLevel = 100,
    this.levelStatGrowth = 0.12,
    this.levelCostBase = 100,
    this.levelCostGrowth = 1.15,
    this.winGoldBase = 50,
    this.winGoldGrowth = 1.1,
    this.loseGoldFraction = 0.2,
    this.stageClearGems = 20,
    this.bossClearGems = 60,
    this.summonSingleCost = 100,
    this.summonTenCost = 900,
    this.rarityWeights = const {'rare': 70, 'epic': 30},
    this.pityEpic = 10,
    this.dupShards = 10,
    this.starShardCosts = const [10, 20, 40, 80],
    this.starStatGrowth = 0.2,
  });

  final int startGold;
  final int startGems;
  final List<String> starterHeroes;
  final int maxLevel;
  final double levelStatGrowth;
  final double levelCostBase;
  final double levelCostGrowth;
  final double winGoldBase;
  final double winGoldGrowth;
  final double loseGoldFraction;
  final int stageClearGems;
  final int bossClearGems;
  final int summonSingleCost;
  final int summonTenCost;

  /// Rarity name -> weight (rarity names match the Rarity enum).
  final Map<String, int> rarityWeights;

  /// An epic is guaranteed after this many pulls without one.
  final int pityEpic;
  final int dupShards;
  final List<int> starShardCosts;
  final double starStatGrowth;

  factory Economy.fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as int?) ?? def;
    const base = Economy();
    return Economy(
      startGold: i('startGold', base.startGold),
      startGems: i('startGems', base.startGems),
      starterHeroes: j['starterHeroes'] == null
          ? base.starterHeroes
          : List<String>.from(j['starterHeroes'] as List),
      maxLevel: i('maxLevel', base.maxLevel),
      levelStatGrowth: d('levelStatGrowth', base.levelStatGrowth),
      levelCostBase: d('levelCostBase', base.levelCostBase),
      levelCostGrowth: d('levelCostGrowth', base.levelCostGrowth),
      winGoldBase: d('winGoldBase', base.winGoldBase),
      winGoldGrowth: d('winGoldGrowth', base.winGoldGrowth),
      loseGoldFraction: d('loseGoldFraction', base.loseGoldFraction),
      stageClearGems: i('stageClearGems', base.stageClearGems),
      bossClearGems: i('bossClearGems', base.bossClearGems),
      summonSingleCost: i('summonSingleCost', base.summonSingleCost),
      summonTenCost: i('summonTenCost', base.summonTenCost),
      rarityWeights: j['rarityWeights'] == null
          ? base.rarityWeights
          : {
              for (final e in (j['rarityWeights'] as Map).entries)
                e.key as String: e.value as int
            },
      pityEpic: i('pityEpic', base.pityEpic),
      dupShards: i('dupShards', base.dupShards),
      starShardCosts: j['starShardCosts'] == null
          ? base.starShardCosts
          : List<int>.from(j['starShardCosts'] as List),
      starStatGrowth: d('starStatGrowth', base.starStatGrowth),
    );
  }

  /// Highest star level a hero can reach.
  int get maxStars => starShardCosts.length + 1;

  /// Stat multiplier of a hero at [level] (level 1 = 1.0).
  double statMult(int level) => 1 + levelStatGrowth * (level - 1);

  /// Stat multiplier from [stars] (1 star = 1.0).
  double starMult(int stars) => 1 + starStatGrowth * (stars - 1);

  /// Gold needed to go from [level] to level + 1.
  int levelUpCost(int level) =>
      min(levelCostBase * pow(levelCostGrowth, level - 1), 1e12).round();

  /// Shards needed to go from [stars] to stars + 1 (null at max stars).
  int? starUpCost(int stars) =>
      stars >= maxStars ? null : starShardCosts[stars - 1];

  /// Gems for [count] summons (10 is discounted).
  int summonCost(int count) =>
      count == 10 ? summonTenCost : summonSingleCost * count;

  /// Gold for finishing a battle on [stage]. A loss still pays a little,
  /// so progress never fully stalls.
  int battleReward(int stage, {required bool won}) {
    final base = min(winGoldBase * pow(winGoldGrowth, stage - 1), 1e12);
    return (won ? base : base * loseGoldFraction).round();
  }
}

/// A hero with its HP and ATK scaled for [level] and [stars].
Unit unitAtLevel(Unit u, int level, Economy e, {int stars = 1}) {
  final m = e.statMult(level) * e.starMult(stars);
  return u.scaled(hp: m, atk: m);
}
