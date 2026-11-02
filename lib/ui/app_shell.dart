import 'package:flutter/material.dart';

import '../game_content.dart';
import 'home_screen.dart';
import 'legacy_tabs.dart';
import 'squad_model.dart';
import 'theme.dart';
import 'widgets.dart';

/// Home / Heroes / Summon with ONE shared bottom nav. Tabs keep their state
/// (IndexedStack). Detail screens (hero detail, equipment, battle) are pushed
/// on top and hide the nav, as on the board.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session});

  final Session session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  late final SquadModel _squad = SquadModel(widget.session);

  void goTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final s = widget.session.content.strings;
    return Scaffold(
      backgroundColor: Pal.bg,
      body: IndexedStack(
        index: _tab,
        children: [
          // Replaced by the board-styled screens in the next stages.
          HomeScreen(session: widget.session, squad: _squad),
          LegacyHeroesTab(session: widget.session),
          LegacySummonTab(session: widget.session),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        index: _tab,
        onTap: goTab,
        items: [
          NavItem(Icons.home_outlined, s.t('ui.nav_home')),
          NavItem(Icons.shield_outlined, s.t('ui.nav_heroes')),
          NavItem(Icons.auto_awesome_outlined, s.t('ui.nav_summon')),
        ],
      ),
    );
  }
}
