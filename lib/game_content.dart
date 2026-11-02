import 'package:flutter/services.dart' show rootBundle;

import 'core/content.dart';
import 'core/models.dart';
import 'l10n/strings.dart';

/// Placeholder stages: enemy unit ids per stage (ids may repeat).
const List<List<String>> stages = [
  ['minotaur', 'shadow_jackal', 'fenrir'],
  ['ammit', 'cerberus_duat', 'frost_sphinx'],
];

const int maxSquadSize = 5;

class GameContent {
  const GameContent(this.heroes, this.monsters, this.strings);

  final List<Unit> heroes;
  final List<Unit> monsters;
  final Strings strings;

  List<Unit> enemiesForStage(int stage) {
    final ids = stages[stage];
    return [
      for (final id in ids) monsters.firstWhere((m) => m.id == id),
    ];
  }
}

Future<GameContent> loadGameContent() async {
  final heroes =
      parseUnits(await rootBundle.loadString('assets/data/heroes.json'));
  final monsters =
      parseUnits(await rootBundle.loadString('assets/data/monsters.json'));
  final strings = await Strings.load();
  return GameContent(heroes, monsters, strings);
}
