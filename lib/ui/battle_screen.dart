import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/battle.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/player.dart';
import '../l10n/strings.dart';
import 'theme.dart';
import 'widgets.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.heroes,
    required this.enemies,
    required this.strings,
    required this.onFinished,
    this.stage,
  });

  final List<Unit> heroes;
  final List<Unit> enemies;
  final Strings strings;

  /// Stage number shown in the title (null = just "Battle").
  final int? stage;

  /// Called once per finished fight; returns the rewards earned.
  final BattleReward Function(bool won) onFinished;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  static const _baseStep = Duration(milliseconds: 450);
  static const _speeds = [1, 2, 4];

  late Battle _battle;
  late List<int> _hp;
  final Queue<BattleEvent> _pending = Queue();
  Timer? _timer;
  int _speedIndex = 0;
  bool _auto = false;
  bool _done = false;
  BattleReward? _reward;
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
    _battle = Battle(widget.heroes, widget.enemies)..auto = _auto;
    _hp = [for (final u in _units) u.baseStats.hp];
    _pending.clear();
    _current = null;
    _done = false;
    _reward = null;
    _startTimer();
  }

  void _advance() {
    if (_pending.isEmpty) {
      if (_battle.finished) {
        _timer?.cancel();
        final reward = widget.onFinished(_battle.winner == Side.heroes);
        setState(() {
          _current = null;
          _done = true;
          _reward = reward;
        });
        return;
      }
      _pending.addAll(_battle.step());
    }
    if (_pending.isEmpty) return;
    final e = _pending.removeFirst();
    setState(() {
      _hp[e.targetIndex] = e.targetHpAfter;
      _current = e;
    });
  }

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
    if (!_done) _startTimer();
  }

  void _toggleAuto() {
    setState(() {
      _auto = !_auto;
      _battle.auto = _auto;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _outcome {
    final s = widget.strings;
    return _battle.winner == Side.heroes
        ? s.t('ui.victory')
        : s.t('ui.defeat');
  }

  String get _banner {
    final e = _current;
    if (e == null) return '';
    final s = widget.strings;
    final round = '${s.t('ui.round')} ${e.round}'
        '${_battle.enraged ? '  -  ${s.t('ui.enraged')}' : ''}';
    if (e.skillId == null) return round;
    return '$round  -  ${s.t('skill.${e.skillId}.name')}';
  }

  /// Floating text and colour on the card that receives the event.
  (String, Color) _floating(BattleEvent e) {
    final s = widget.strings;
    const heal = Color(0xFF7CF0B0);
    return switch (e.kind) {
      EventKind.attack => e.amount == 0
          ? (s.t('status.block'), Pal.muted)
          : ('-${formatNumber(e.amount)}', Colors.white),
      EventKind.heal => ('+${formatNumber(e.amount)}', heal),
      EventKind.stun => (s.t('status.stun'), Pal.goldLight),
      EventKind.skip => (s.t('status.skip'), Pal.goldLight),
      EventKind.taunt => (s.t('status.taunt'), Pal.goldLight),
      EventKind.buff => (s.t('status.buff'), Pal.goldLight),
      EventKind.shield => (s.t('status.shield'), Pal.goldLight),
      EventKind.reflect => (s.t('status.reflect'), Pal.goldLight),
      EventKind.silence => (s.t('status.silence'), Pal.goldLight),
    };
  }

  @override
  Widget build(BuildContext context) {
    final hCount = widget.heroes.length;
    final eCount = widget.enemies.length;
    final s = widget.strings;
    return Scaffold(
      backgroundColor: Pal.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.26, 0.42, 0.62, 1],
            colors: [
              Color(0xFF2A3F8A),
              Color(0xFF5A6FC0),
              Color(0xFFD9A86A),
              Color(0xFF9A7040),
              Color(0xFF4A3220),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _ArenaPainter())),
              Column(
                children: [
                  _topBar(s),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _zone(hCount, eCount)),
                        SizedBox(
                          height: 36,
                          child: Center(
                            child: Text(
                              _done ? '' : _banner,
                              style: nunito(15, color: Pal.cream, shadows: true),
                            ),
                          ),
                        ),
                        Expanded(child: _zone(0, hCount)),
                      ],
                    ),
                  ),
                  _controls(s, hCount),
                ],
              ),
              if (_done) Positioned.fill(child: _resultOverlay(s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(Strings s) {
    final title = widget.stage != null
        ? '${s.t('ui.stage')} ${widget.stage}'
        : s.t('ui.battle');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Material(
            color: Pal.scrim,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(),
              child: Semantics(
                button: true,
                label: s.t('ui.back'),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.chevron_left_rounded,
                      color: Pal.cream, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: lilita(22, shadows: const [
                  Shadow(color: Color(0xB31B1030), offset: Offset(0, 2))
                ])),
          ),
          Material(
            color: Pal.scrim,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _cycleSpeed,
              child: Semantics(
                button: true,
                label: s.t('ui.speed'),
                child: SizedBox(
                  width: 52,
                  height: 44,
                  child: Center(
                    child: Text('${_speeds[_speedIndex]}x',
                        style: nunito(15, color: Pal.gold)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Figures for combined-list indexes [from, from + count).
  Widget _zone(int from, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = from; i < from + count; i++)
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  // Slight stagger like the board.
                  alignment: (i - from).isOdd
                      ? const Alignment(0, 0.35)
                      : const Alignment(0, -0.15),
                  child: _figure(i, box.maxWidth),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _figure(int index, double w) {
    final unit = _units[index];
    final hp = _hp[index];
    final max = unit.baseStats.hp;
    final dead = hp <= 0;
    final current = _current;
    final acting = current?.actorIndex == index;
    final targeted = current?.targetIndex == index;
    final float = (targeted && current != null) ? _floating(current) : null;
    final isHero = index < widget.heroes.length;
    final size = (w - 4).clamp(52.0, 104.0).toDouble();
    final ring = targeted
        ? (current?.kind == EventKind.heal
            ? const Color(0x805FD38D)
            : const Color(0x80FF6B5B))
        : acting
            ? const Color(0x80F2C14E)
            : const Color(0x4D000000);
    return Opacity(
      opacity: dead ? 0.35 : 1,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 10,
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Pal.bg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Bar(
                value: max > 0 ? hp / max : 0,
                color: isHero ? Pal.green : Pal.red,
                height: 7,
                track: Pal.track,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: size,
              height: size * 1.1,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: size * 0.8,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ring,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    child: AnimatedScale(
                      scale: acting ? 1.12 : 1,
                      duration: const Duration(milliseconds: 150),
                      // Swap point for real art: replace HeroBust /
                      // MonsterFigure (lib/ui/widgets.dart) with the real figures.
                      child: isHero
                          ? HeroBust(unit: unit, size: size)
                          : MonsterFigure(unit: unit, size: size * 0.8),
                    ),
                  ),
                  if (float != null)
                    Positioned(
                      top: 10,
                      left: -10,
                      right: -10,
                      child: Center(
                        child: FittedBox(
                          child: Text(
                            float.$1,
                            style: lilita(24, color: float.$2, shadows: const [
                              Shadow(
                                  color: Pal.outline, offset: Offset(0, 2))
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              widget.strings.t(unit.nameKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: nunito(12, shadows: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(Strings s, int hCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.38],
          colors: [Color(0x0014122B), Pal.bg],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (var i = 0; i < hCount; i++) _ultButton(i, s)],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                button: true,
                toggled: _auto,
                label: s.t('ui.auto'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _toggleAuto,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                    decoration: BoxDecoration(
                      color: Pal.panel,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.t('ui.auto'),
                            style: nunito(14, letterSpacing: 1)),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 26,
                          padding: const EdgeInsets.all(3),
                          alignment: _auto
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: _auto ? Pal.green : Pal.dim,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: Pal.bg, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    s.t('ui.ult_hint'),
                    textAlign: TextAlign.right,
                    style: nunito(12, weight: 600, color: Pal.muted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ultButton(int i, Strings s) {
    final unit = widget.heroes[i];
    final fighter = _battle.all[i];
    final dead = _hp[i] <= 0;
    final ready = !dead && !_done && fighter.ultReady;
    final queued = ready && fighter.ultQueued;
    final progress = (fighter.energy / maxEnergy).clamp(0.0, 1.0).toDouble();
    final state = ready ? s.t('ui.ult_ready') : s.t('ui.ult_charging');
    return Semantics(
      button: true,
      enabled: ready && !_auto,
      label: '${s.t(unit.nameKey)}: ${s.t('ui.ult')}, $state',
      child: GestureDetector(
        onTap: ready && !_auto
            ? () => setState(() => _battle.queueUltimate(i))
            : null,
        child: Opacity(
          opacity: dead ? 0.35 : 1,
          child: SizedBox(
            width: 66,
            height: 66,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: roleColor(unit.role),
                ready: ready,
                queued: queued,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mythColors(unit.mythology).$2,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: HeroBust(unit: unit, size: 46),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultOverlay(Strings s) {
    final r = _reward;
    final won = _battle.winner == Side.heroes;
    return Container(
      color: const Color(0x8014122B),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Pal.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: won ? Pal.gold : Pal.dim, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_outcome,
                style: lilita(40, color: won ? Pal.gold : Pal.muted)),
            const SizedBox(height: 10),
            if (r != null) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: [
                  _rewardRow(const CoinIcon(), '+${formatNumber(r.gold)}'),
                  if (r.gems > 0)
                    _rewardRow(const GemIcon(), '+${formatNumber(r.gems)}'),
                ],
              ),
              if (r.drops.isNotEmpty) ...[
                const SizedBox(height: 10),
                GoldLabel(s.t('ui.drops')),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final i in r.drops)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: rarityColor(i.rarity), width: 2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(s.t('rarity.${i.rarity.name}'),
                            style: nunito(12, color: rarityColor(i.rarity))),
                      ),
                  ],
                ),
              ],
              if (r.scrapGold > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${s.t('ui.scrapped')} ${formatNumber(r.scrapGold)} ${s.t('ui.gold')}',
                  textAlign: TextAlign.center,
                  style: nunito(12, weight: 700, color: Pal.muted),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DarkButton(
                    label: s.t('ui.back'),
                    height: 54,
                    fontSize: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GoldButton(
                    label: s.t('ui.replay'),
                    height: 54,
                    fontSize: 18,
                    onPressed: () => setState(_start),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardRow(Widget icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(text, style: nunito(20)),
        ],
      );
}

/// Energy ring around an ultimate button: fills as energy charges, turns
/// gold with a halo when the ultimate is ready.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.ready,
    required this.queued,
  });

  final double progress;
  final Color color;
  final bool ready;
  final bool queued;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = queued ? 7 : 5;
    canvas.drawCircle(c, r, Paint()..color = Pal.panel);
    canvas.drawCircle(c, r, stroke..color = Pal.track2);
    if (ready) {
      canvas.drawCircle(
          c,
          r + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0x80FFE08A));
      canvas.drawCircle(c, r, stroke..color = Pal.gold);
    } else if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
          2 * math.pi * progress, false, stroke..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.ready != ready ||
      old.queued != queued;
}

/// Sun, pillars and ground behind the fight (from the board).
class _ArenaPainter extends CustomPainter {
  const _ArenaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * 0.86, h * 0.075), 30,
        Paint()..color = const Color(0x99FFE08A));
    final pillar = Paint()..color = const Color(0x29FFFFFF);
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.13, 30, h * 0.31), pillar);
    canvas.drawRect(Rect.fromLTWH(w * 0.23, h * 0.18, 24, h * 0.26), pillar);
    canvas.drawRect(Rect.fromLTWH(w * 0.71, h * 0.18, 24, h * 0.26), pillar);
    canvas.drawRect(Rect.fromLTWH(w * 0.89, h * 0.13, 30, h * 0.31), pillar);
    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.43)
          ..quadraticBezierTo(w / 2, h * 0.39, w, h * 0.43)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0x8CB88A55));
    final soft = Paint()..color = const Color(0x0D000000);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.70), width: w * 0.9, height: 60),
        soft);
  }

  @override
  bool shouldRepaint(_ArenaPainter old) => false;
}
