import 'package:flutter/material.dart';

import '../core/models.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import 'hero_detail_screen.dart';
import 'squad_model.dart';
import 'theme.dart';
import 'widgets.dart';

/// Heroes tab (board: Heroes.dc.html): collection grid with mythology tabs
/// and role filters. The board's "Sort" button is not built (no sort system).
class HeroesScreen extends StatefulWidget {
  const HeroesScreen({super.key, required this.session, required this.squad});

  final Session session;
  final SquadModel squad;

  @override
  State<HeroesScreen> createState() => _HeroesScreenState();
}

class _HeroesScreenState extends State<HeroesScreen> {
  String? _myth; // null = All
  final Set<Role> _roles = {};

  @override
  Widget build(BuildContext context) {
    final c = widget.session.content;
    final player = widget.session.player;
    final s = c.strings;
    final myths = <String>[];
    for (final h in c.heroes) {
      if (!myths.contains(h.mythology)) myths.add(h.mythology);
    }
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final owned = c.heroes.where((h) => player.state.owns(h.id)).length;
          final shown = [
            for (final h in c.heroes)
              if ((_myth == null || h.mythology == _myth) &&
                  (_roles.isEmpty || _roles.contains(h.role)))
                h
          ];
          // Owned heroes first, then locked ones (stable order inside each).
          shown.sort((a, b) {
            final oa = player.state.owns(a.id) ? 0 : 1;
            final ob = player.state.owns(b.id) ? 0 : 1;
            return oa.compareTo(ob);
          });
          return Column(
            children: [
              TabHeader(
                title: s.t('ui.nav_heroes'),
                trailing: Text('$owned / ${c.heroes.length} ${s.t('ui.collected')}',
                    style: nunito(14, color: Pal.muted)),
              ),
              _tabs(s, myths),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    for (final r in Role.values) ...[
                      SquareIconButton(
                        icon: roleIcon(r),
                        label: '${s.t('ui.filter')}: ${s.t('role.${r.name}')}',
                        color: roleColor(r),
                        selected: _roles.contains(r),
                        onPressed: () => setState(() {
                          if (!_roles.remove(r)) _roles.add(r);
                        }),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(s.t('ui.no_heroes'),
                            style: nunito(14, color: Pal.muted)))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 152,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (context, i) => _card(context, shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabs(Strings s, List<String> myths) {
    Widget tab(String label, String? myth) {
      final on = _myth == myth;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _myth = myth),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: on ? Pal.gold : Colors.transparent, width: 3),
              ),
            ),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nunito(14, color: on ? Pal.gold : Pal.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Pal.track)),
      ),
      child: Row(
        children: [
          tab(s.t('ui.all'), null),
          for (final m in myths) tab(s.t('myth.$m'), m),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Unit h) {
    final c = widget.session.content;
    final s = c.strings;
    final st = widget.session.player.state;
    final owns = st.owns(h.id);
    final (a, b) = mythColors(h.mythology);
    return Semantics(
      button: true,
      label: owns
          ? '${s.t(h.nameKey)}, ${s.t('ui.level')} ${st.levelOf(h.id)}'
          : '${s.t(h.nameKey)}, ${s.t('ui.locked')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: owns
            ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => HeroDetailScreen(
                      session: widget.session,
                      squad: widget.squad,
                      heroId: h.id),
                ))
            : () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.t('ui.locked_hint')))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: owns ? null : Pal.panel,
                    gradient: owns
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [a, b])
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final size = box.maxWidth < box.maxHeight
                                ? box.maxWidth
                                : box.maxHeight;
                            final bust = HeroBust(unit: h, size: size);
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: owns
                                  ? bust
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                          Color(0xFF2E2A58), BlendMode.srcATop),
                                      child: bust),
                            );
                          },
                        ),
                      ),
                      if (owns) ...[
                        Positioned(
                            left: 6, top: 6, child: RoleBadge(role: h.role)),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Pal.scrimStrong,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '${s.t('ui.level')} ${st.levelOf(h.id)}',
                                style: nunito(12)),
                          ),
                        ),
                      ] else
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Icon(Icons.lock_outline,
                              color: Pal.muted, size: 22),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            if (owns)
              StarRow(count: st.starsOf(h.id))
            else
              const SizedBox(height: 13),
            const SizedBox(height: 4),
            Text(s.t(h.nameKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nunito(13, color: owns ? Pal.cream : Pal.muted)),
          ],
        ),
      ),
    );
  }
}
