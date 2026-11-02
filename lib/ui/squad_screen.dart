import 'package:flutter/material.dart';

import '../core/economy.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/stages.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import '../state/player_controller.dart';
import 'battle_screen.dart';

const _bg = Color(0xFF14122B);
const _panel = Color(0xFF1D1A3D);
const _gold = Color(0xFFF2C14E);
const _cream = Color(0xFFF3EEDC);
const _muted = Color(0xFFB9B4D6);

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key, required this.session});

  final Session session;

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  // Default squad: the first three heroes.
  late final Set<String> _selected =
      widget.session.content.heroes.take(3).map((h) => h.id).toSet();

  /// null = follow the highest stage the player may attempt.
  int? _stage;

  @override
  Widget build(BuildContext context) {
    final c = widget.session.content;
    final player = widget.session.player;
    final s = c.strings;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final maxStage = player.state.nextStage;
        final stage = (_stage ?? maxStage).clamp(1, maxStage);
        final chapter = chapterAt(stage, c.stageConfig);
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            foregroundColor: _cream,
            title: Text(s.t('ui.squad')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${s.t('ui.gold')}: ${formatNumber(player.state.gold)}',
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '${s.t('ui.pick_squad')}  (${_selected.length}/$maxSquadSize)',
                    style: const TextStyle(color: _muted),
                  ),
                ),
                Expanded(child: _heroList(c, player)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Text(
                        '${s.t('ui.chapter')} ${chapterNumber(stage, c.stageConfig)}: '
                        '${s.t(chapter.titleKey)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _gold, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        s.t(chapter.introKey),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: stage > 1
                                ? () => setState(() => _stage = stage - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: _gold,
                          ),
                          Text(
                            '${s.t('ui.stage')} $stage'
                            '${c.isBoss(stage) ? '  -  ${s.t('ui.boss')}' : ''}',
                            style: const TextStyle(
                                color: _cream,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                          IconButton(
                            onPressed: stage < maxStage
                                ? () => setState(() => _stage = stage + 1)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: _gold,
                          ),
                        ],
                      ),
                      Text(
                        c
                            .enemiesForStage(stage)
                            .map((u) => s.t(u.nameKey))
                            .join(', '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _gold, foregroundColor: _bg),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => BattleScreen(
                                  heroes: [
                                    for (final h in c.heroes)
                                      if (_selected.contains(h.id))
                                        unitAtLevel(
                                            h,
                                            player.state.levelOf(h.id),
                                            c.economy)
                                  ],
                                  enemies: c.enemiesForStage(stage),
                                  strings: s,
                                  onFinished: (won) => player.recordBattle(
                                      stage: stage, won: won),
                                ),
                              )),
                      child: Text(s.t('ui.battle')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroList(GameContent c, PlayerController player) {
    final s = c.strings;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final h in c.heroes) _heroTile(c, player, h, s),
      ],
    );
  }

  Widget _heroTile(GameContent c, PlayerController player, Unit h, Strings s) {
    final level = player.state.levelOf(h.id);
    final stats = unitAtLevel(h, level, c.economy).baseStats;
    final canUp = player.state.canLevelUp(h.id, c.economy);
    final maxed = level >= c.economy.maxLevel;
    final cost = c.economy.levelUpCost(level);
    return Card(
      color: _panel,
      child: CheckboxListTile(
        value: _selected.contains(h.id),
        activeColor: _gold,
        checkColor: _bg,
        onChanged: (v) => setState(() {
          if (v == true) {
            if (_selected.length < maxSquadSize) _selected.add(h.id);
          } else {
            _selected.remove(h.id);
          }
        }),
        title: Text('${s.t(h.nameKey)}  ${s.t('ui.level')} $level',
            style:
                const TextStyle(color: _cream, fontWeight: FontWeight.w800)),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor(h.role),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(s.t('role.${h.role.name}'),
                  style: const TextStyle(
                      color: Color(0xFF1B1030),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'HP ${formatNumber(stats.hp)}  ATK ${formatNumber(stats.atk)}',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ),
            ),
          ],
        ),
        secondary: maxed
            ? null
            : FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _bg,
                  minimumSize: const Size(64, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: canUp ? () => player.levelUp(h.id) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, size: 16),
                    const SizedBox(width: 4),
                    Text(formatNumber(cost)),
                  ],
                ),
              ),
      ),
    );
  }
}
