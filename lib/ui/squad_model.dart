import 'package:flutter/foundation.dart';

import '../core/equipment.dart';
import '../core/models.dart';
import '../game_content.dart';

/// The squad the player will take into battle, plus the stage picked on Home.
/// UI state only (not saved yet). Lives in the app shell so Home, Heroes and
/// Hero Detail share it.
class SquadModel extends ChangeNotifier {
  SquadModel(this.session) {
    // Default squad: the first three owned heroes (same as before).
    final c = session.content;
    _ids.addAll(c.heroes
        .where((h) => session.player.state.owns(h.id))
        .take(3)
        .map((h) => h.id));
  }

  final Session session;
  final List<String> _ids = [];

  /// null = follow the highest stage the player may attempt.
  int? _stage;

  List<String> get ids => List.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);
  bool get isFull => _ids.length >= maxSquadSize;
  bool get isEmpty => _ids.isEmpty;

  /// Add or remove a hero. Returns false if the squad is full.
  bool toggle(String id) {
    if (_ids.remove(id)) {
      notifyListeners();
      return true;
    }
    if (isFull) return false;
    _ids.add(id);
    notifyListeners();
    return true;
  }

  /// Squad units in roster order (front of the roster = front row).
  List<Unit> units() => [
        for (final h in session.content.heroes)
          if (_ids.contains(h.id) && session.player.state.owns(h.id)) h
      ];

  /// The selected stage, kept within what the player may attempt.
  int stage() {
    final max = session.player.state.nextStage;
    return (_stage ?? max).clamp(1, max).toInt();
  }

  void setStage(int stage) {
    _stage = stage;
    notifyListeners();
  }

  /// Heroes with level, stars and equipment applied, ready for Battle.
  List<Unit> battleUnits() {
    final c = session.content;
    final st = session.player.state;
    return [
      for (final h in units())
        unitWithEquipment(h, st.levelOf(h.id), c.economy,
            stars: st.starsOf(h.id), bonus: st.bonusFor(h.id, c.equipment))
    ];
  }
}
