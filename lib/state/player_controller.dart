import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/economy.dart';
import '../core/equipment.dart';
import '../core/models.dart';
import '../core/player.dart';

/// Holds the player's progress, saves it locally after every change.
/// (Cloud save with Firebase comes later; the JSON format stays the same.)
class PlayerController extends ChangeNotifier {
  PlayerController._(this._prefs, this.state, this.economy, this.equipment);

  static const _key = 'theomyth_save_v1';

  final SharedPreferences _prefs;
  final PlayerState state;
  final Economy economy;
  final EquipmentConfig equipment;

  static Future<PlayerController> load(
      Economy economy, EquipmentConfig equipment) async {
    final prefs = await SharedPreferences.getInstance();
    PlayerState state;
    try {
      final raw = prefs.getString(_key);
      state = raw == null
          ? PlayerState.initial(economy)
          : PlayerState.fromJson(
              jsonDecode(raw) as Map<String, dynamic>, economy);
    } catch (_) {
      // Corrupt save: start fresh rather than crash.
      state = PlayerState.initial(economy);
    }
    final controller = PlayerController._(prefs, state, economy, equipment);
    if (state.lastCollectMs == null) {
      // First run (or old save): idle gold starts counting now.
      state.lastCollectMs = controller.nowMs;
      controller._save();
    }
    return controller;
  }

  /// Replaceable clock (tests).
  DateTime Function() clock = DateTime.now;

  int get nowMs => clock().millisecondsSinceEpoch;

  int pendingIdle() => state.idleGoldPending(nowMs, economy);

  int get maxIdleGold => state.maxIdleGold(economy);

  /// Returns the gold collected.
  int collectIdle({int multiplier = 1}) {
    final amount =
        state.collectIdle(nowMs, economy, multiplier: multiplier);
    _save();
    notifyListeners();
    return amount;
  }

  void _save() => _prefs.setString(_key, jsonEncode(state.toJson()));

  bool levelUp(String heroId) {
    final ok = state.levelUp(heroId, economy);
    if (ok) {
      _save();
      notifyListeners();
    }
    return ok;
  }

  bool starUp(String heroId) {
    final ok = state.starUp(heroId, economy);
    if (ok) {
      _save();
      notifyListeners();
    }
    return ok;
  }

  final Random _random = Random();

  /// Null if not enough gems.
  List<SummonResult>? summon(int count, List<Unit> heroes) {
    final results = state.summon(count, heroes, economy, _random);
    if (results != null) {
      _save();
      notifyListeners();
    }
    return results;
  }

  BattleReward recordBattle({
    required int stage,
    required bool won,
    required bool isBoss,
  }) {
    final reward = state.recordBattle(
        stage: stage,
        won: won,
        isBoss: isBoss,
        economy: economy,
        equipment: equipment,
        rnd: _random);
    _save();
    notifyListeners();
    return reward;
  }

  bool equipItem(String heroId, int itemId) =>
      _changed(state.equip(heroId, itemId, equipment));

  bool unequipSlot(String heroId, String slot) =>
      _changed(state.unequip(heroId, slot));

  bool upgradeItem(int itemId) =>
      _changed(state.upgradeItem(itemId, equipment));

  /// Returns the gold received, or null if the item cannot be sold.
  int? sellItem(int itemId) {
    final gold = state.sellItem(itemId, equipment);
    if (gold != null) _changed(true);
    return gold;
  }

  bool _changed(bool ok) {
    if (ok) {
      _save();
      notifyListeners();
    }
    return ok;
  }
}
