// Pure Dart. Placeholder economy numbers come from assets/data/economy.json.

import 'dart:math' show min, pow;

import 'models.dart';

class Economy {
  const Economy({
    this.startGold = 500,
    this.maxLevel = 100,
    this.levelStatGrowth = 0.12,
    this.levelCostBase = 100,
    this.levelCostGrowth = 1.15,
    this.winGoldBase = 50,
    this.winGoldGrowth = 1.1,
    this.loseGoldFraction = 0.2,
  });

  final int startGold;
  final int maxLevel;
  final double levelStatGrowth;
  final double levelCostBase;
  final double levelCostGrowth;
  final double winGoldBase;
  final double winGoldGrowth;
  final double loseGoldFraction;

  factory Economy.fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return Economy(
      startGold: (j['startGold'] as int?) ?? 500,
      maxLevel: (j['maxLevel'] as int?) ?? 100,
      levelStatGrowth: d('levelStatGrowth', 0.12),
      levelCostBase: d('levelCostBase', 100),
      levelCostGrowth: d('levelCostGrowth', 1.15),
      winGoldBase: d('winGoldBase', 50),
      winGoldGrowth: d('winGoldGrowth', 1.1),
      loseGoldFraction: d('loseGoldFraction', 0.2),
    );
  }

  /// Stat multiplier of a hero at [level] (level 1 = 1.0).
  double statMult(int level) => 1 + levelStatGrowth * (level - 1);

  /// Gold needed to go from [level] to level + 1.
  int levelUpCost(int level) =>
      min(levelCostBase * pow(levelCostGrowth, level - 1), 1e12).round();

  /// Gold for finishing a battle on [stage]. A loss still pays a little,
  /// so progress never fully stalls.
  int battleReward(int stage, {required bool won}) {
    final base = min(winGoldBase * pow(winGoldGrowth, stage - 1), 1e12);
    return (won ? base : base * loseGoldFraction).round();
  }
}

/// A hero with its HP and ATK scaled for [level].
Unit unitAtLevel(Unit u, int level, Economy e) {
  final m = e.statMult(level);
  return u.scaled(hp: m, atk: m);
}
