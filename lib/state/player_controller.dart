import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/economy.dart';
import '../core/player.dart';

/// Holds the player's progress, saves it locally after every change.
/// (Cloud save with Firebase comes later; the JSON format stays the same.)
class PlayerController extends ChangeNotifier {
  PlayerController._(this._prefs, this.state, this.economy);

  static const _key = 'theomyth_save_v1';

  final SharedPreferences _prefs;
  final PlayerState state;
  final Economy economy;

  static Future<PlayerController> load(Economy economy) async {
    final prefs = await SharedPreferences.getInstance();
    PlayerState state;
    try {
      final raw = prefs.getString(_key);
      state = raw == null
          ? PlayerState.initial(economy)
          : PlayerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt save: start fresh rather than crash.
      state = PlayerState.initial(economy);
    }
    return PlayerController._(prefs, state, economy);
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

  /// Returns the gold earned.
  int recordBattle({required int stage, required bool won}) {
    final reward =
        state.recordBattle(stage: stage, won: won, economy: economy);
    _save();
    notifyListeners();
    return reward;
  }
}
