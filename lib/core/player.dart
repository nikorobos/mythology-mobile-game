// Pure Dart player progress. Saved as JSON (see lib/state).

import 'economy.dart';

class PlayerState {
  PlayerState({
    this.gold = 0,
    Map<String, int>? heroLevels,
    this.highestStageCleared = 0,
  }) : heroLevels = heroLevels ?? {};

  factory PlayerState.initial(Economy e) => PlayerState(gold: e.startGold);

  int gold;
  final Map<String, int> heroLevels;
  int highestStageCleared;

  int levelOf(String heroId) => heroLevels[heroId] ?? 1;

  /// Highest stage the player may attempt.
  int get nextStage => highestStageCleared + 1;

  bool canLevelUp(String heroId, Economy e) =>
      levelOf(heroId) < e.maxLevel && gold >= e.levelUpCost(levelOf(heroId));

  bool levelUp(String heroId, Economy e) {
    if (!canLevelUp(heroId, e)) return false;
    gold -= e.levelUpCost(levelOf(heroId));
    heroLevels[heroId] = levelOf(heroId) + 1;
    return true;
  }

  /// Applies a finished battle. Returns the gold earned.
  int recordBattle({
    required int stage,
    required bool won,
    required Economy economy,
  }) {
    final reward = economy.battleReward(stage, won: won);
    gold += reward;
    if (won && stage > highestStageCleared) highestStageCleared = stage;
    return reward;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'gold': gold,
        'heroLevels': heroLevels,
        'highestStageCleared': highestStageCleared,
      };

  factory PlayerState.fromJson(Map<String, dynamic> j) => PlayerState(
        gold: (j['gold'] as int?) ?? 0,
        heroLevels: {
          for (final e in ((j['heroLevels'] as Map?) ?? const {}).entries)
            e.key as String: e.value as int
        },
        highestStageCleared: (j['highestStageCleared'] as int?) ?? 0,
      );
}
