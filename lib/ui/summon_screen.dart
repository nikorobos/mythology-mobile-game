import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/player.dart';
import '../game_content.dart';
import 'battle_screen.dart';

const _bg = Color(0xFF14122B);
const _panel = Color(0xFF1D1A3D);
const _gold = Color(0xFFF2C14E);
const _cream = Color(0xFFF3EEDC);
const _muted = Color(0xFFB9B4D6);

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9AA3B2),
      Rarity.rare => const Color(0xFF4FB3E6),
      Rarity.epic => const Color(0xFFB07CFF),
      Rarity.legendary => const Color(0xFFF2C14E),
    };

class SummonScreen extends StatefulWidget {
  const SummonScreen({super.key, required this.session});

  final Session session;

  @override
  State<SummonScreen> createState() => _SummonScreenState();
}

class _SummonScreenState extends State<SummonScreen> {
  List<SummonResult> _last = const [];
  bool _failed = false;

  void _pull(int count) {
    final c = widget.session.content;
    final results = widget.session.player.summon(count, c.heroes);
    setState(() {
      _failed = results == null;
      if (results != null) _last = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.session.content;
    final player = widget.session.player;
    final s = c.strings;
    final eco = c.economy;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final st = player.state;
        final left = (eco.pityEpic - st.pity).clamp(1, eco.pityEpic);
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            foregroundColor: _cream,
            title: Text(s.t('ui.summon')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${s.t('ui.gems')}: ${formatNumber(st.gems)}',
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${s.t('ui.pity')}: $left ${s.t('ui.pulls')}',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _failed
                        ? Center(
                            child: Text(s.t('ui.not_enough_gems'),
                                style: const TextStyle(color: _gold)))
                        : _last.isEmpty
                            ? const SizedBox.shrink()
                            : ListView(
                                children: [
                                  for (final r in _last) _resultTile(r),
                                ],
                              ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _pullButton(1)),
                      const SizedBox(width: 12),
                      Expanded(child: _pullButton(10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pullButton(int count) {
    final c = widget.session.content;
    final s = c.strings;
    final cost = c.economy.summonCost(count);
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: _gold, foregroundColor: _bg),
        onPressed: () => _pull(count),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.t(count == 1 ? 'ui.summon_x1' : 'ui.summon_x10'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('${formatNumber(cost)} ${s.t('ui.gems')}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _resultTile(SummonResult r) {
    final c = widget.session.content;
    final s = c.strings;
    final hero = c.heroes.firstWhere((h) => h.id == r.heroId);
    return Card(
      color: _panel,
      child: ListTile(
        leading: Container(
          width: 10,
          height: 40,
          decoration: BoxDecoration(
            color: rarityColor(hero.rarity),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(s.t(hero.nameKey),
            style:
                const TextStyle(color: _cream, fontWeight: FontWeight.w800)),
        subtitle: Text(s.t('rarity.${hero.rarity.name}'),
            style: TextStyle(color: rarityColor(hero.rarity), fontSize: 12)),
        trailing: Text(
          r.isNew
              ? s.t('ui.new')
              : '+${r.shardsGained} ${s.t('ui.shards')}',
          style: TextStyle(
              color: r.isNew ? _gold : _muted, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
