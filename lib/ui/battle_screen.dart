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
const _red = Color(0xFFFF5C5C);
const _green = Color(0xFF5FD38D);

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
  static const _baseStep = Duration(milliseconds: 450);
  static const _speeds = [1, 2, 4];

  late BattleResult _result;
  late List<int> _hp;
  Timer? _timer;
  int _next = 0;
  int _speedIndex = 0;
  BattleEvent? _current;

  List<Unit> get _units => [...widget.heroes, ...widget.enemies];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _baseStep.inMilliseconds ~/ _speeds[_speedIndex]),
      (_) => _advance(),
    );
  }

  void _start() {
    _result = simulateBattle(widget.heroes, widget.enemies);
    _hp = [for (final u in _units) u.baseStats.hp];
    _next = 0;
    _current = null;
    _startTimer();
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

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
    if (!_finished) _startTimer();
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

  String get _banner {
    final e = _current;
    if (e == null) return '';
    final s = widget.strings;
    final round = '${s.t('ui.round')} ${e.round}';
    if (e.skillId == null) return round;
    return '$round  -  ${s.t('skill.${e.skillId}.name')}';
  }

  /// Floating text and colour on the card that receives the event.
  (String, Color)? _floating(BattleEvent e) {
    final s = widget.strings;
    return switch (e.kind) {
      EventKind.attack => ('-${e.amount}', _red),
      EventKind.heal => ('+${e.amount}', _green),
      EventKind.stun => (s.t('status.stun'), _gold),
      EventKind.skip => (s.t('status.skip'), _gold),
      EventKind.taunt => (s.t('status.taunt'), _gold),
      EventKind.buff => (s.t('status.buff'), _gold),
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
        actions: [
          TextButton(
            onPressed: _cycleSpeed,
            child: Text('${_speeds[_speedIndex]}x',
                style: const TextStyle(
                    color: _gold, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _row(hCount, widget.enemies.length)),
            SizedBox(
              height: 72,
              child: Center(
                child: _finished
                    ? Text(_outcome,
                        style: const TextStyle(
                            color: _gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w900))
                    : Text(_banner,
                        style: const TextStyle(color: _muted, fontSize: 16)),
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
          for (var i = from; i < from + count; i++) Expanded(child: _card(i)),
        ],
      ),
    );
  }

  Widget _card(int index) {
    final unit = _units[index];
    final hp = _hp[index];
    final max = unit.baseStats.hp;
    final dead = hp <= 0;
    final current = _current;
    final acting = current?.actorIndex == index;
    final targeted = current?.targetIndex == index;
    final float = (targeted && current != null) ? _floating(current) : null;
    return Opacity(
      opacity: dead ? 0.35 : 1,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: targeted
                ? (float?.$2 ?? _red)
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
                color: _green,
                backgroundColor: const Color(0xFF3A3466),
              ),
            ),
            const SizedBox(height: 4),
            Text('$hp / $max',
                style: const TextStyle(color: _muted, fontSize: 11)),
            SizedBox(
              height: 18,
              child: float == null
                  ? null
                  : FittedBox(
                      child: Text(float.$1,
                          style: TextStyle(
                              color: float.$2, fontWeight: FontWeight.w900)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
