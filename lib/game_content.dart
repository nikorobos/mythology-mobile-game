import 'package:flutter/services.dart' show rootBundle;

import 'core/content.dart';
import 'core/models.dart';
import 'core/stages.dart';
import 'l10n/strings.dart';

const int maxSquadSize = 5;

class GameContent {
  const GameContent(this.heroes, this.monsters, this.stageConfig, this.strings);

  final List<Unit> heroes;
  final List<Unit> monsters;
  final StageConfig stageConfig;
  final Strings strings;

  /// Enemy team for any stage number (endless).
  List<Unit> enemiesForStage(int stage) =>
      buildStage(stage, monsters, stageConfig);

  bool isBoss(int stage) => isBossStage(stage, stageConfig);
}

Future<GameContent> loadGameContent() async {
  final heroes =
      parseUnits(await rootBundle.loadString('assets/data/heroes.json'));
  final monsters =
      parseUnits(await rootBundle.loadString('assets/data/monsters.json'));
  final config =
      parseStageConfig(await rootBundle.loadString('assets/data/stages.json'));
  final strings = await Strings.load();
  return GameContent(heroes, monsters, config, strings);
}
