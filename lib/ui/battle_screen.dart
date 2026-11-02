import 'dart:async';

import 'package:flutter/material.dart';

import '../core/battle.dart';
import '../core/models.dart';
import '../l10n/strings.dart';

const _bg = Color(0xFF14122B);
const _panel = Color(0xFF1D1A3D);
const _gold = Color(0xFFF2C14E);
const _cream = Color(0xFFF3EEDC);
const _muted = Color(0xFFB9B4D6);

Color roleColor(Role r) => switch (r) {
      Role.tank => const Color(0xFF6FA8FF),
      Role.dps => const Color(0xFFFF8A5C),
      Role.healer => const Color(0xFF5FD38D),
      Role.support => const Color(0xFFC79BFF),
    };

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.heroes,
    required this.enemies,
    required this.strings,
  });

  final List<Unit> heroes;
  final List<Unit> enemies;
  final Strings strings;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  static const _step = Duration(milliseconds: 450);

  late BattleResult _result;
  late List<int> _hp;
  Timer? _timer;
  int _next = 0;
  BattleEvent? _current;

  List<Unit> get _units => [...widget.heroes, ...widget.enemies];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _result = simulateBattle(widget.heroes, widget.enemies);
    _hp = [for (final u in _units) u.baseStats.hp];
    _next = 0;
    _current = null;
    _timer = Timer.periodic(_step, (_) => _advance());
  }

  void _advance() {
    if (_next >= _result.events.length) {
      _timer?.cancel();
      setState(() => _current = null);
      return;
    }
    final e = _result.events[_next++];
    setState(() {
      _hp[e.targetIndex] = e.targetHpAfter;
      _current = e;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _finished => _next >= _result.events.length;

  String get _outcome {
    final s = widget.strings;
    return switch (_result.winner) {
      Side.heroes => s.t('ui.victory'),
      Side.enemies => s.t('ui.defeat'),
      null => s.t('ui.draw'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final hCount = widget.heroes.length;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _cream,
        title: Text(widget.strings.t('ui.battle')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _row(hCount, widget.enemies.length)),
            SizedBox(
              height: 72,
              child: Center(
                child: _finished
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_outcome,
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900)),
                        ],
                      )
                    : Text(
                        _current == null
                            ? ''
                            : '${widget.strings.t('ui.round')} ${_current!.round}',
                        style: const TextStyle(color: _muted, fontSize: 16),
                      ),
              ),
            ),
            Expanded(child: _row(0, hCount)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _gold, foregroundColor: _bg),
                  onPressed: _finished ? () => setState(_start) : null,
                  child: Text(widget.strings.t('ui.replay')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cards for combined-list indexes [from, from + count).
  Widget _row(int from, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (var i = from; i < from + count; i++)
            Expanded(child: _card(i)),
        ],
      ),
    );
  }

  Widget _card(int index) {
    final unit = _units[index];
    final hp = _hp[index];
    final max = unit.baseStats.hp;
    final dead = hp <= 0;
    final acting = _current?.actorIndex == index;
    final hit = _current?.targetIndex == index;
    return Opacity(
      opacity: dead ? 0.35 : 1,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hit
                ? const Color(0xFFFF5C5C)
                : acting
                    ? _gold
                    : const Color(0xFF1B1030),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.strings.t(unit.nameKey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _cream, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor(unit.role),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.strings.t('role.${unit.role.name}'),
                  style: const TextStyle(
                      color: Color(0xFF1B1030),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (hp / max).clamp(0.0, 1.0),
                minHeight: 8,
                color: const Color(0xFF5FD38D),
                backgroundColor: const Color(0xFF3A3466),
              ),
            ),
            const SizedBox(height: 4),
            Text('$hp / $max',
                style: const TextStyle(color: _muted, fontSize: 11)),
            SizedBox(
              height: 18,
              child: hit
                  ? Text('-${_current!.damage}',
                      style: const TextStyle(
                          color: Color(0xFFFF5C5C),
                          fontWeight: FontWeight.w900))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
