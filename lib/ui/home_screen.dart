import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/stages.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import 'battle_screen.dart';
import 'idle_panel.dart';
import 'squad_model.dart';
import 'theme.dart';
import 'widgets.dart';

/// Home tab (board: Home.dc.html): currencies, chapter scene, realms,
/// idle rewards, squad and the big BATTLE button.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session, required this.squad});

  final Session session;
  final SquadModel squad;

  @override
  Widget build(BuildContext context) {
    final c = session.content;
    final player = session.player;
    final s = c.strings;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([player, squad]),
        builder: (context, _) {
          final maxStage = player.state.nextStage;
          final stage = squad.stage();
          final chapter = chapterAt(stage, c.stageConfig);
          final inChapter = (stage - 1) % c.stageConfig.bossEvery + 1;
          final units = squad.units();
          return Column(
            children: [
              _Header(session: session),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    _Scene(
                      session: session,
                      mythology: chapter.mythology,
                      chapterNo: chapterNumber(stage, c.stageConfig),
                      title: s.t(chapter.titleKey),
                      stage: stage,
                      inChapter: inChapter,
                      chapterLength: c.stageConfig.bossEvery,
                      isBoss: c.isBoss(stage),
                      squadUnits: units,
                      canPrev: stage > 1,
                      canNext: stage < maxStage,
                      onPrev: () => squad.setStage(stage - 1),
                      onNext: () => squad.setStage(stage + 1),
                    ),
                    const SizedBox(height: 8),
                    Text(s.t(chapter.introKey),
                        style: nunito(12, weight: 600, color: Pal.muted)),
                    Text(
                      '${s.t('ui.enemies')}: '
                      '${c.enemiesForStage(stage).map((u) => s.t(u.nameKey)).toSet().join(', ')}',
                      style: nunito(12, weight: 600, color: Pal.muted),
                    ),
                    const SizedBox(height: 12),
                    _Realms(session: session, current: chapter.mythology),
                    const SizedBox(height: 12),
                    IdlePanel(session: session),
                    const SizedBox(height: 12),
                    _SquadStrip(session: session, squad: squad),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: GoldButton(
                  label: s.t('ui.battle'),
                  height: 60,
                  fontSize: 28,
                  letterSpacing: 2,
                  depth: 5,
                  onPressed: squad.isEmpty
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => BattleScreen(
                              heroes: squad.battleUnits(),
                              enemies: c.enemiesForStage(stage),
                              strings: s,
                              stage: stage,
                              onFinished: (won) => player.recordBattle(
                                  stage: stage,
                                  won: won,
                                  isBoss: c.isBoss(stage)),
                            ),
                          )),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session.content.strings;
    return ListenableBuilder(
      listenable: session.player,
      builder: (context, _) {
        final st = session.player.state;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Mini logo. (Player level / avatar from the board is not a
              // game system yet, so it is not shown.)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THEO',
                      style: cinzel(11, color: Pal.gold, letterSpacing: 6)),
                  Text('MYTH', style: cinzel(24, weight: 900)),
                ],
              ),
              Row(
                children: [
                  CurrencyPill(
                      currency: Currency.gold,
                      text: formatNumber(st.gold),
                      semanticLabel: s.t('ui.gold')),
                  const SizedBox(width: 8),
                  CurrencyPill(
                      currency: Currency.gems,
                      text: formatNumber(st.gems),
                      semanticLabel: s.t('ui.gems')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ scene

(Color, Color, Color) _sky(String myth) => switch (myth) {
      'greek' => (
          const Color(0xFFF29E4C),
          const Color(0xFFC0536B),
          const Color(0xFF2A3F8A)
        ),
      'norse' => (
          const Color(0xFF9BD0F0),
          const Color(0xFF2E8FC4),
          const Color(0xFF1B3A5E)
        ),
      'egyptian' => (
          const Color(0xFFFFD27A),
          const Color(0xFFC98A38),
          const Color(0xFF5A3410)
        ),
      _ => (
          const Color(0xFFB07CFF),
          const Color(0xFF6B43B8),
          const Color(0xFF2A1F5E)
        ),
    };

class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 358, size.height / 296);
    canvas.drawCircle(const Offset(268, 118), 44,
        Paint()..color = const Color(0xBFFFE08A));
    Path tri(double x1, double y1, double x2, double y2, double x3, double y3) =>
        Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2)
          ..lineTo(x3, y3)
          ..close();
    canvas.drawPath(tri(40, 200, 110, 130, 180, 200),
        Paint()..color = const Color(0x381B1030));
    canvas.drawPath(tri(150, 200, 240, 120, 330, 200),
        Paint()..color = const Color(0x291B1030));
    final col = Paint()..color = const Color(0x4D1B1030);
    for (final x in [214.0, 238.0, 262.0, 286.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 150, 14, 60), col);
    }
    canvas.drawPath(tri(208, 150, 306, 150, 257, 122), col);
    canvas.drawRect(const Rect.fromLTWH(0, 236, 358, 60),
        Paint()..color = const Color(0x731B1030));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}

class _Scene extends StatelessWidget {
  const _Scene({
    required this.session,
    required this.mythology,
    required this.chapterNo,
    required this.title,
    required this.stage,
    required this.inChapter,
    required this.chapterLength,
    required this.isBoss,
    required this.squadUnits,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  final Session session;
  final String mythology;
  final int chapterNo;
  final String title;
  final int stage;
  final int inChapter;
  final int chapterLength;
  final bool isBoss;
  final List<Unit> squadUnits;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = session.content.strings;
    final (top, mid, bottom) = _sky(mythology);
    // Center hero first, then left and right (like the board).
    Widget bust(int i, double size, double shift) => i < squadUnits.length
        ? Transform.translate(
            offset: Offset(shift, 0),
            child: HeroBust(unit: squadUnits[i], size: size))
        : SizedBox(width: size, height: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 296,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.48, 1],
            colors: [top, mid, bottom],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _ScenePainter())),
            Positioned(
              left: 18,
              top: 16,
              right: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.t('ui.chapter')} $chapterNo'.toUpperCase(),
                    style: labelStyle(color: const Color(0xFFFFF0B8)),
                  ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: lilita(26, shadows: const [
                      Shadow(color: Color(0x991B1030), offset: Offset(0, 2))
                    ]),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  bust(1, 96, 14),
                  bust(0, 120, 0),
                  bust(2, 96, -14),
                ],
              ),
            ),
            Positioned(
              left: 6,
              right: 14,
              bottom: 2,
              child: Row(
                children: [
                  IconButton(
                    tooltip: s.t('ui.prev_stage'),
                    onPressed: canPrev ? onPrev : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 28,
                    color: Pal.cream,
                    disabledColor: Pal.dim,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  Expanded(
                    child: Text(
                      '${s.t('ui.stage')} $stage'
                      '${isBoss ? '  ·  ${s.t('ui.boss')}' : ''}',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: nunito(13),
                    ),
                  ),
                  IconButton(
                    tooltip: s.t('ui.next_stage'),
                    onPressed: canNext ? onNext : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    iconSize: 28,
                    color: Pal.cream,
                    disabledColor: Pal.dim,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  for (var i = 1; i <= chapterLength; i++)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= inChapter ? Pal.gold : Pal.dim,
                        boxShadow: i == inChapter
                            ? const [
                                BoxShadow(
                                    color: Color(0x66F2C14E), spreadRadius: 3)
                              ]
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- realms

class _Realms extends StatelessWidget {
  const _Realms({required this.session, required this.current});

  final Session session;
  final String current;

  @override
  Widget build(BuildContext context) {
    final c = session.content;
    final s = c.strings;
    // Distinct mythologies in chapter order. Display only: chapters advance
    // by playing, not by picking a realm.
    final myths = <String>[];
    for (final ch in c.stageConfig.chapters) {
      if (!myths.contains(ch.mythology)) myths.add(ch.mythology);
    }
    return Row(
      children: [
        for (var i = 0; i < myths.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _RealmChip(
            label: s.t('myth.${myths[i]}'),
            myth: myths[i],
            active: myths[i] == current,
          )),
        ],
      ],
    );
  }
}

class _RealmChip extends StatelessWidget {
  const _RealmChip(
      {required this.label, required this.myth, required this.active});

  final String label;
  final String myth;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final (a, b) = mythColors(myth);
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active ? null : Pal.panel,
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [a, b])
            : null,
        border: active ? Border.all(color: Pal.gold, width: 3) : null,
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: nunito(13,
            color: active ? Pal.cream : Pal.muted, letterSpacing: 1),
      ),
    );
  }
}

// ------------------------------------------------------------------ squad

class _SquadStrip extends StatelessWidget {
  const _SquadStrip({required this.session, required this.squad});

  final Session session;
  final SquadModel squad;

  @override
  Widget build(BuildContext context) {
    final s = session.content.strings;
    final units = squad.units();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GoldLabel(s.t('ui.your_squad')),
            const SizedBox(width: 8),
            Text('${units.length}/5',
                style: nunito(12, color: Pal.muted)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showSquadPicker(context, session, squad),
          child: Semantics(
            button: true,
            label: s.t('ui.squad_pick_title'),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: i < units.length
                          ? LayoutBuilder(
                              builder: (context, box) => PortraitSquare(
                                  unit: units[i], size: box.maxWidth))
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Pal.dim, width: 2),
                              ),
                              child: const Icon(Icons.add,
                                  color: Pal.muted, size: 22),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet to choose up to five owned heroes.
void showSquadPicker(BuildContext context, Session session, SquadModel squad) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Pal.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scroll) => _SquadPicker(
            session: session, squad: squad, controller: scroll),
      ),
    ),
  );
}

class _SquadPicker extends StatelessWidget {
  const _SquadPicker(
      {required this.session, required this.squad, required this.controller});

  final Session session;
  final SquadModel squad;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final c = session.content;
    final s = c.strings;
    final owned = [
      for (final h in c.heroes)
        if (session.player.state.owns(h.id)) h
    ];
    return ListenableBuilder(
      listenable: squad,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(s.t('ui.squad_pick_title'),
                          style: lilita(22))),
                  Text('${squad.ids.length}/$maxSquadSize',
                      style: nunito(14, color: Pal.muted)),
                ],
              ),
            ),
            Expanded(
              child: owned.isEmpty
                  ? Center(
                      child: Text(s.t('ui.no_heroes'),
                          style: nunito(14, color: Pal.muted)))
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final h in owned) _row(context, h, s),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, Unit h, Strings s) {
    final inSquad = squad.contains(h.id);
    final blocked = !inSquad && squad.isFull;
    final level = session.player.state.levelOf(h.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Pal.panel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: blocked ? null : () => squad.toggle(h.id),
          child: Opacity(
            opacity: blocked ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  PortraitSquare(unit: h, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t(h.nameKey), style: nunito(16)),
                        Text(
                          '${s.t('role.${h.role.name}')}  ·  '
                          '${s.t('ui.level')} $level',
                          style: nunito(12, weight: 700, color: roleColor(h.role)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    inSquad ? Icons.check_circle : Icons.circle_outlined,
                    color: inSquad ? Pal.gold : Pal.muted,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
