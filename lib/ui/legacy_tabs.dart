import 'package:flutter/material.dart';

import '../game_content.dart';
import 'squad_screen.dart';
import 'summon_screen.dart';

// TEMPORARY (stage 1 only): the old screens hosted inside the new shell so
// the app stays playable while each screen is restyled. Deleted in later stages.

class LegacyHeroesTab extends StatelessWidget {
  const LegacyHeroesTab({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => SquadScreen(session: session);
}

class LegacySummonTab extends StatelessWidget {
  const LegacySummonTab({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => SummonScreen(session: session);
}
