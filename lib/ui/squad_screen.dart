import 'package:flutter/material.dart';

import '../game_content.dart';
import 'battle_screen.dart';

const _bg = Color(0xFF14122B);
const _panel = Color(0xFF1D1A3D);
const _gold = Color(0xFFF2C14E);
const _cream = Color(0xFFF3EEDC);
const _muted = Color(0xFFB9B4D6);

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key, required this.content});

  final GameContent content;

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  // Default squad: the first three heroes.
  late final Set<String> _selected =
      widget.content.heroes.take(3).map((h) => h.id).toSet();
  int _stage = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final s = c.strings;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _cream,
        title: Text(s.t('ui.squad')),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final h in c.heroes)
                    Card(
                      color: _panel,
                      child: CheckboxListTile(
                        value: _selected.contains(h.id),
                        activeColor: _gold,
                        checkColor: _bg,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            if (_selected.length < maxSquadSize) {
                              _selected.add(h.id);
                            }
                          } else {
                            _selected.remove(h.id);
                          }
                        }),
                        title: Text(s.t(h.nameKey),
                            style: const TextStyle(
                                color: _cream, fontWeight: FontWeight.w800)),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4, right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(s.t('myth.${h.mythology}'),
                                  style: const TextStyle(
                                      color: _muted, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text('${s.t('ui.stage')}:',
                      style: const TextStyle(color: _cream)),
                  const SizedBox(width: 12),
                  for (var i = 0; i < stages.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${i + 1}'),
                        selected: _stage == i,
                        selectedColor: _gold,
                        onSelected: (_) => setState(() => _stage = i),
                      ),
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
                                  if (_selected.contains(h.id)) h
                              ],
                              enemies: c.enemiesForStage(_stage),
                              strings: s,
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
  }
}
