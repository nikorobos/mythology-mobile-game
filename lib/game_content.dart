import 'package:flutter/services.dart' show rootBundle;

import 'core/content.dart';
import 'core/models.dart';
import 'l10n/strings.dart';

const int maxSquadSize = 5;

class GameContent {
  const GameContent(this.heroes, this.monsters, this.stages, this.strings);

  final List<Unit> heroes;
  final List<Unit> monsters;
  final List<StageDef> stages;
  final Strings strings;

  /// Enemy team of a stage, with the stage's difficulty multipliers applied.
  List<Unit> enemiesForStage(int stage) => enemiesFor(monsters, stages[stage]);
}

List<Unit> enemiesFor(List<Unit> monsters, StageDef stage) => [
      for (final id in stage.enemies)
        monsters
            .firstWhere((m) => m.id == id)
            .scaled(hp: stage.hpMult, atk: stage.atkMult),
    ];

Future<GameContent> loadGameContent() async {
  final heroes =
      parseUnits(await rootBundle.loadString('assets/data/heroes.json'));
  final monsters =
      parseUnits(await rootBundle.loadString('assets/data/monsters.json'));
  final stages =
      parseStages(await rootBundle.loadString('assets/data/stages.json'));
  final strings = await Strings.load();
  return GameContent(heroes, monsters, stages, strings);
}
