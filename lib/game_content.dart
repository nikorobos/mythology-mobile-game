import 'package:flutter/services.dart' show rootBundle;

import 'core/content.dart';
import 'core/economy.dart';
import 'core/models.dart';
import 'core/stages.dart';
import 'l10n/strings.dart';
import 'services/ad_service.dart';
import 'state/player_controller.dart';

const int maxSquadSize = 5;

class GameContent {
  const GameContent(
    this.heroes,
    this.monsters,
    this.stageConfig,
    this.economy,
    this.strings,
  );

  final List<Unit> heroes;
  final List<Unit> monsters;
  final StageConfig stageConfig;
  final Economy economy;
  final Strings strings;

  /// Enemy team for any stage number (endless).
  List<Unit> enemiesForStage(int stage) =>
      buildStage(stage, monsters, stageConfig);

  bool isBoss(int stage) => isBossStage(stage, stageConfig);
}

/// Everything the UI needs: static content + the player's saved progress.
class Session {
  const Session(this.content, this.player, this.ads);

  final GameContent content;
  final PlayerController player;
  final AdService ads;
}

Future<Session> loadSession() async {
  final heroes =
      parseUnits(await rootBundle.loadString('assets/data/heroes.json'));
  final monsters =
      parseUnits(await rootBundle.loadString('assets/data/monsters.json'));
  final config =
      parseStageConfig(await rootBundle.loadString('assets/data/stages.json'));
  final economy =
      parseEconomy(await rootBundle.loadString('assets/data/economy.json'));
  final strings = await Strings.load();
  final player = await PlayerController.load(economy);
  return Session(
    GameContent(heroes, monsters, config, economy, strings),
    player,
    StubAdService(),
  );
}
