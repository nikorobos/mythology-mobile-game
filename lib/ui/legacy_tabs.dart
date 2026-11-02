import 'package:flutter/material.dart';

import '../game_content.dart';
import 'idle_panel.dart';
import 'squad_screen.dart';
import 'summon_screen.dart';
import 'theme.dart';

// TEMPORARY (stage 1 only): the old screens hosted inside the new shell so
// the app stays playable while each screen is restyled. Deleted in later stages.

class LegacyHomeTab extends StatelessWidget {
  const LegacyHomeTab({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('THEOMYTH', style: lilita(40)),
            const SizedBox(height: 24),
            IdlePanel(session: session),
          ],
        ),
      ),
    );
  }
}

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
