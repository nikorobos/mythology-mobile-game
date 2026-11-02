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

/// Opaque color from an 0xRRGGBB int with an alpha 0..1 (no deprecated APIs).
Color _a(int rgb, double alpha) => Color.fromARGB(
    (alpha.clamp(0.0, 1.0) * 255).round(), (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);

/// One floating number / label over a fighter (damage, heal, status).
class _Floater {
  _Floater(this.index, this.text, this.color, this.big, this.startMs);
  final int index;
  final String text;
  final Color color;
  final bool big;
  final int startMs;
}

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

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  static const _baseStepMs = 450;
  static const _speeds = [1, 2, 4];
  static const _cutMs = [1100, 650, 350];

  late Battle _battle;
  late List<int> _hp;
  final Queue<BattleEvent> _pending = Queue();
  Timer? _timer;
  int _speedIndex = 0;
  bool _auto = false;
  bool _done = false;
  BattleReward? _reward;
  BattleEvent? _current;

  // ---- animation state
  /// Looping clock for idle motion.
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  /// Per-event clock: hit reactions, projectiles, impact effects.
  late final AnimationController _fx = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));

  /// Per-action clock: the actor's lunge out and back (spans all its events).
  late final AnimationController _act = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));

  /// Ultimate cut-in.
  late final AnimationController _cut = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  /// Fighters entering at the start of the fight.
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  final Stopwatch _clock = Stopwatch()..start();
  final List<_Floater> _floaters = [];
  late List<GlobalKey> _cellKeys;
  final GlobalKey _arenaKey = GlobalKey();

  bool _newBatch = true;
  int _busyUntilMs = 0;
  BattleEvent? _cutFor;
  int _cutActor = 0;
  String _cutSkill = '';

  int _actorIndex = -1;
  bool _fxNewAction = false;
  bool _fxUlt = false;
  bool _fxBig = false;
  bool _actionMelee = false;
  bool _actionAttack = false;
  Offset _lungeVec = Offset.zero;
  int _tagActor = -1;
  String _tagText = '';
  int _tagStartMs = 0;

  List<Unit> get _units => [...widget.heroes, ...widget.enemies];
  int get _tickMs => _baseStepMs ~/ _speeds[_speedIndex];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _tickMs), (_) => _advance());
  }

  void _start() {
    _battle = Battle(widget.heroes, widget.enemies)..auto = _auto;
    _hp = [for (final u in _units) u.baseStats.hp];
    _cellKeys = [for (var i = 0; i < _units.length; i++) GlobalKey()];
    _pending.clear();
    _floaters.clear();
    _current = null;
    _done = false;
    _reward = null;
    _newBatch = true;
    _busyUntilMs = _clock.elapsedMilliseconds + 900; // let fighters enter
    _cutFor = null;
    _actorIndex = -1;
    _entry.forward(from: 0);
    _startTimer();
  }

  bool _isUlt(BattleEvent e) {
    final id = e.skillId;
    if (id == null) return false;
    return _units[e.actorIndex].ultimate?.id == id;
  }

  void _advance() {
    if (_clock.elapsedMilliseconds < _busyUntilMs) return;
    if (_pending.isEmpty) {
      if (_battle.finished) {
        _timer?.cancel();
        final reward = widget.onFinished(_battle.winner == Side.heroes);
        setState(() {
          _current = null;
          _actorIndex = -1;
          _done = true;
          _reward = reward;
        });
        return;
      }
      final batch = _battle.step();
      if (batch.isEmpty) return;
      _pending.addAll(batch);
      _newBatch = true;
    }
    final e = _pending.first;
    final newAction = _newBatch;
    if (newAction && _isUlt(e) && !identical(_cutFor, e)) {
      _startCutIn(e);
      return;
    }
    _pending.removeFirst();
    _newBatch = false;
    _play(e, newAction);
  }

  void _startCutIn(BattleEvent e) {
    final ms = _cutMs[_speedIndex];
    _cutFor = e;
    _cutActor = e.actorIndex;
    final unit = _units[e.actorIndex];
    _cutSkill = unit.ultimate == null
        ? ''
        : widget.strings.t(unit.ultimate!.nameKey);
    _busyUntilMs = _clock.elapsedMilliseconds + ms + 60;
    _cut.duration = Duration(milliseconds: ms);
    setState(() {});
    _cut.forward(from: 0);
  }

  /// Where a fighter's sprite box is, in the arena's coordinates.
  Offset? _pos(int i) {
    final ctx = _cellKeys[i].currentContext;
    final arena = _arenaKey.currentContext;
    if (ctx == null || arena == null) return null;
    final rb = ctx.findRenderObject();
    final ab = arena.findRenderObject();
    if (rb is! RenderBox || ab is! RenderBox || !rb.attached || !ab.attached) {
      return null;
    }
    return ab.globalToLocal(rb.localToGlobal(rb.size.center(Offset.zero)));
  }

  void _play(BattleEvent e, bool newAction) {
    final now = _clock.elapsedMilliseconds;
    final actor = _units[e.actorIndex];
    final target = _units[e.targetIndex];
    final ult = _isUlt(e);
    final big = e.kind == EventKind.attack &&
        (ult || e.amount >= target.baseStats.hp * 0.2);
    final isHeroActor = e.actorIndex < widget.heroes.length;

    if (newAction) {
      _actorIndex = e.actorIndex;
      _actionAttack = e.kind == EventKind.attack && e.actorIndex != e.targetIndex;
      _actionMelee = actor.range == Range.melee;
      final from = _pos(e.actorIndex);
      final to = _pos(e.targetIndex);
      if (_actionAttack && _actionMelee) {
        _lungeVec = (from != null && to != null)
            ? (to - from) * 0.72
            : Offset(0, isHeroActor ? -90 : 90);
      } else {
        _lungeVec = Offset.zero;
      }
      // Action clock spans every event of this action.
      final count = _pending.length + 1;
      // (_pending still holds this action's remaining events + maybe later
      // ones; the action clock is only visual, so a slightly long span is ok.)
      final span = (_tickMs * math.min(count, 6) * 0.95).round();
      _act.duration = Duration(milliseconds: math.max(span, 240));
      _act.forward(from: 0);

      if (e.skillId != null && !ult) {
        _tagActor = e.actorIndex;
        _tagText = widget.strings.t('skill.${e.skillId}.name');
        _tagStartMs = now;
      }
    }

    _floaters.removeWhere((f) => now - f.startMs > 1300);
    final f = _floating(e);
    setState(() {
      _hp[e.targetIndex] = e.targetHpAfter;
      _current = e;
      _fxNewAction = newAction;
      _fxUlt = ult;
      _fxBig = big;
      _floaters.add(_Floater(e.targetIndex, f.$1, f.$2, big || ult, now));
    });
    _fx.duration = Duration(milliseconds: math.max((_tickMs * 0.95).round(), 90));
    _fx.forward(from: 0);
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
    _idle.dispose();
    _fx.dispose();
    _act.dispose();
    _cut.dispose();
    _entry.dispose();
    super.dispose();
  }

  String get _outcome {
    final s = widget.strings;
    return _battle.winner == Side.heroes ? s.t('ui.victory') : s.t('ui.defeat');
  }

  String get _banner {
    final e = _current;
    if (e == null) return '';
    final s = widget.strings;
    final round = '${s.t('ui.round')} ${e.round}'
        '${_battle.enraged ? '  -  ${s.t('ui.enraged')}' : ''}';
    return round;
  }

  /// Floating text and colour on the fighter that receives the event.
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

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _fx, _act, _cut, _entry]),
            builder: (context, _) => Stack(
              children: [
                const Positioned.fill(
                    child: CustomPaint(painter: _ArenaPainter())),
                Column(
                  children: [
                    _topBar(s),
                    Expanded(child: _arena(s)),
                    _controls(s),
                  ],
                ),
                if (_cut.isAnimating) Positioned.fill(child: _cutIn(s)),
                if (_done) Positioned.fill(child: _resultOverlay(s)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The fighting area: both rows, effects, floating numbers. Shakes on big hits.
  Widget _arena(Strings s) {
    final hCount = widget.heroes.length;
    final eCount = widget.enemies.length;
    final e = _current;
    final t = _fx.value;
    final hitT = _fxNewAction ? 0.28 : 0.05;
    var shake = Offset.zero;
    if (e != null && _fxBig && t > hitT) {
      final k = 1 - (t - hitT) / (1 - hitT);
      final amp = (_fxUlt ? 11.0 : 5.0) * k;
      shake = Offset(math.sin(t * 70) * amp, math.cos(t * 83) * amp * 0.6);
    }
    final now = _clock.elapsedMilliseconds;
    return Transform.translate(
      offset: shake,
      child: Stack(
        key: _arenaKey,
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Expanded(child: _zone(hCount, eCount)),
              SizedBox(
                height: 30,
                child: Center(
                  child: Text(
                    _done ? '' : _banner,
                    style: nunito(14, color: Pal.cream, shadows: true),
                  ),
                ),
              ),
              Expanded(child: _zone(0, hCount)),
            ],
          ),
          // Impact / projectile / aura effects.
          if (e != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FxPainter(
                    kind: e.kind,
                    t: t,
                    hitT: hitT,
                    from: _pos(e.actorIndex),
                    to: _pos(e.targetIndex),
                    ranged: _units[e.actorIndex].range == Range.ranged,
                    ult: _fxUlt,
                    newAction: _fxNewAction,
                    rgb: _fxRgb(e),
                  ),
                ),
              ),
            ),
          // Skill name tag over the acting unit.
          if (_tagActor >= 0 && now - _tagStartMs < 900) _skillTag(now),
          // Floating numbers.
          for (final f in _floaters)
            if (now - f.startMs < 1200) _floater(f, now),
        ],
      ),
    );
  }

  /// Effect color as 0xRRGGBB.
  int _fxRgb(BattleEvent e) {
    if (_fxUlt) return 0xF2C14E;
    return switch (e.kind) {
      EventKind.heal => 0x5FD38D,
      EventKind.buff => 0xF2C14E,
      EventKind.shield => 0x5BE0FF,
      EventKind.taunt => 0xFF8A5C,
      EventKind.reflect => 0xD7E3F4,
      EventKind.silence => 0xC79BFF,
      EventKind.stun || EventKind.skip => 0xFFE08A,
      EventKind.attack => _roleRgb(_units[e.actorIndex].role),
    };
  }

  static int _roleRgb(Role r) => switch (r) {
        Role.tank => 0x6FA8FF,
        Role.dps => 0xFF8A5C,
        Role.healer => 0x5FD38D,
        Role.support => 0xC79BFF,
      };

  Widget _skillTag(int now) {
    final p = _pos(_tagActor);
    if (p == null) return const SizedBox.shrink();
    final age = (now - _tagStartMs) / 900.0;
    final op = age < 0.15 ? age / 0.15 : (age > 0.75 ? (1 - age) / 0.25 : 1.0);
    return Positioned(
      left: p.dx - 80,
      top: p.dy - 92 - 10 * age,
      width: 160,
      child: IgnorePointer(
        child: Opacity(
          opacity: op.clamp(0.0, 1.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Pal.scrimStrong,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Pal.gold, width: 2),
              ),
              child: Text(_tagText, style: nunito(12, color: Pal.goldLight)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _floater(_Floater f, int now) {
    final p = _pos(f.index);
    if (p == null) return const SizedBox.shrink();
    final age = ((now - f.startMs) / 900.0).clamp(0.0, 1.0);
    final pop = age < 0.14
        ? 0.5 + (age / 0.14) * 0.9
        : (age < 0.3 ? 1.4 - ((age - 0.14) / 0.16) * 0.4 : 1.0);
    final rise = 54 * Curves.easeOut.transform(age);
    final op = age > 0.7 ? 1 - (age - 0.7) / 0.3 : 1.0;
    final size = f.big ? 34.0 : 24.0;
    return Positioned(
      left: p.dx - 70,
      top: p.dy - 46 - rise,
      width: 140,
      child: IgnorePointer(
        child: Opacity(
          opacity: op.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: pop,
            child: Center(child: _OutlinedText(f.text, size, f.color)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (var i = from; i < from + count; i++)
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: (i - from).isOdd
                      ? const Alignment(0, 0.5)
                      : const Alignment(0, -0.25),
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
    final fighter = _battle.all[index];
    final hp = _hp[index];
    final max = unit.baseStats.hp;
    final dead = hp <= 0;
    final isHero = index < widget.heroes.length;
    final spriteH = (w * 1.5).clamp(74.0, 150.0).toDouble();
    final spriteW = spriteH * 0.75;
    final e = _current;
    final acting = _actorIndex == index;
    final targeted = e != null && e.targetIndex == index && e.actorIndex != index;
    final t = _fx.value;
    final hitT = _fxNewAction ? 0.28 : 0.05;

    // ---- idle motion
    final ph = _idle.value * 2 * math.pi + index * 0.9;
    var dx = 0.0;
    var dy = dead ? 0.0 : math.sin(ph) * 2.5;
    var scaleY = dead ? 1.0 : 1 + 0.012 * math.sin(ph * 1.0 + 1);
    var scaleX = 1.0;
    var rot = 0.0;
    if (_done && !dead) {
      final winners = (_battle.winner == Side.heroes) == isHero;
      if (winners) dy = -math.sin(_idle.value * 2 * math.pi * 3 + index).abs() * 12;
    }

    // ---- entry (slide in from off-screen, staggered)
    final delay = ((index % 5) * 0.07);
    final ent = Curves.easeOutBack
        .transform(((_entry.value - delay) / 0.65).clamp(0.0, 1.0));
    dy += (1 - ent) * (isHero ? 160.0 : -160.0);

    // ---- action pose
    if (acting && !_done) {
      final total = _act.duration!.inMilliseconds.toDouble();
      final ms = _act.value * total;
      final outMs = math.min(130.0, total * 0.35);
      final backMs = math.min(150.0, total * 0.35);
      double p;
      if (ms < outMs) {
        p = Curves.easeOut.transform(ms / outMs);
      } else if (ms > total - backMs) {
        p = 1 - Curves.easeIn.transform((ms - (total - backMs)) / backMs);
      } else {
        p = 1.0;
      }
      if (_actionAttack && _actionMelee) {
        dx += _lungeVec.dx * p;
        dy += _lungeVec.dy * p;
        // Squash into the hit, slight tilt toward the target.
        scaleX *= 1 + 0.10 * p;
        scaleY *= 1 - 0.06 * p;
        rot += (_lungeVec.dx.sign) * 0.12 * p;
      } else if (_actionAttack) {
        // Ranged: lean back, then snap forward as the shot leaves.
        dy += (isHero ? 8.0 : -8.0) * p;
        scaleY *= 1 + 0.06 * p;
      } else {
        // Casting: rise and glow.
        dy -= 14 * math.sin(math.pi * p);
        scaleX *= 1 + 0.08 * p;
        scaleY *= 1 + 0.08 * p;
      }
    }

    // ---- hit reaction
    var flash = 0.0;
    if (targeted && e.kind == EventKind.attack && t > hitT) {
      final k = ((t - hitT) / (1 - hitT)).clamp(0.0, 1.0);
      flash = 1 - k;
      final push = (isHero ? 1.0 : -1.0);
      dx += math.sin(k * 34) * 9 * (1 - k);
      dy += push * 8 * (1 - k);
      scaleY *= 1 - 0.10 * (1 - k);
      scaleX *= 1 + 0.08 * (1 - k);
    }
    if (e != null && e.kind == EventKind.skip && e.actorIndex == index) {
      dx += math.sin(t * 40) * 6 * (1 - t);
    }

    final ready = isHero && !dead && !_done && fighter.ultReady;
    final pulse = 0.5 + 0.5 * math.sin(_idle.value * 2 * math.pi * 2);
    final ring = ready
        ? _a(0xF2C14E, 0.35 + 0.35 * pulse)
        : (acting && !_done
            ? _a(0xF2C14E, 0.35)
            : (targeted ? _a(0xFF6B5B, 0.35) : _a(0x000000, 0.22)));

    Widget sprite = UnitSprite(unit: unit, height: spriteH);
    if (flash > 0) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(_a(0xFF4A3A, 0.6 * flash), BlendMode.srcATop),
        child: sprite,
      );
    }

    final body = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: dead ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOut,
      child: sprite,
      builder: (context, v, child) {
        final sat = 1 - v;
        const lr = 0.2126, lg = 0.7152, lb = 0.0722;
        return Opacity(
          opacity: 1 - 0.62 * v,
          child: Transform.translate(
            offset: Offset(0, 22 * v),
            child: Transform.rotate(
              angle: v * (isHero ? -1.0 : 1.0) * 0.5,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(<double>[
                  lr + (1 - lr) * sat, lg * (1 - sat), lb * (1 - sat), 0, 0,
                  lr * (1 - sat), lg + (1 - lg) * sat, lb * (1 - sat), 0, 0,
                  lr * (1 - sat), lg * (1 - sat), lb + (1 - lb) * sat, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: child,
              ),
            ),
          ),
        );
      },
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: ready && !_auto
          ? () => setState(() => _battle.queueUltimate(index))
          : null,
      child: SizedBox(
        width: math.max(spriteW, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: dead ? 0 : 1,
              child: Container(
                width: spriteW * 0.9,
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
            ),
            const SizedBox(height: 4),
            // The cell key is on this untransformed box: effects measure it.
            SizedBox(
              key: _cellKeys[index],
              width: spriteW,
              height: spriteH,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: spriteW * 0.9,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ring,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.identity()
                          ..rotateZ(rot)
                          ..scale(scaleX, scaleY),
                        child: RepaintBoundary(child: body),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: dead ? 0.4 : 1,
              child: Text(
                widget.strings.t(unit.nameKey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: nunito(12, shadows: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- controls

  Widget _controls(Strings s) {
    final hCount = widget.heroes.length;
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
    final pulse = ready ? 1 + 0.07 * math.sin(_idle.value * 2 * math.pi * 2) : 1.0;
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
          child: Transform.scale(
            scale: pulse,
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
                      child: HeroBust(unit: unit, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ultimate

  /// Full-screen ultimate cut-in: dim, burst, hero slides in, skill name.
  Widget _cutIn(Strings s) {
    final t = _cut.value;
    final unit = _units[_cutActor];
    final isHero = _cutActor < widget.heroes.length;
    final env = t < 0.14 ? t / 0.14 : (t > 0.86 ? (1 - t) / 0.14 : 1.0);
    final slideIn = Curves.easeOutCubic.transform((t / 0.28).clamp(0.0, 1.0));
    final slideOut = t > 0.86 ? (t - 0.86) / 0.14 : 0.0;
    final accent = isHero ? roleColor(unit.role) : Pal.red;
    final accentRgb = isHero ? _roleRgb(unit.role) : 0xFF6B5B;
    final sign = isHero ? -1.0 : 1.0; // heroes come from the left
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final spriteH = h * 0.5;
      final drift = (t - 0.28) * 26 * (isHero ? 1 : -1);
      final spriteDx = sign * ((1 - slideIn) * w * 0.7 + slideOut * w * 0.5) + drift;
      final textDx = -sign * ((1 - slideIn) * w * 0.6 + slideOut * w * 0.5);
      return IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
                child: ColoredBox(color: _a(0x07060F, 0.72 * env.clamp(0.0, 1.0)))),
            Positioned.fill(
              child: CustomPaint(
                painter: _CutinPainter(
                    t: t, env: env.clamp(0.0, 1.0), rgb: accentRgb, fromLeft: isHero),
              ),
            ),
            Positioned(
              left: isHero ? w * 0.02 : null,
              right: isHero ? null : w * 0.02,
              top: h * 0.5 - spriteH * 0.52,
              child: Transform.translate(
                offset: Offset(spriteDx, 0),
                child: Opacity(
                  opacity: env.clamp(0.0, 1.0),
                  child: UnitSprite(unit: unit, height: spriteH),
                ),
              ),
            ),
            Positioned(
              left: isHero ? w * 0.40 : w * 0.06,
              right: isHero ? w * 0.04 : w * 0.40,
              top: h * 0.5 - 54,
              child: Transform.translate(
                offset: Offset(textDx, 0),
                child: Opacity(
                  opacity: env.clamp(0.0, 1.0),
                  child: Column(
                    crossAxisAlignment:
                        isHero ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      Text(
                        s.t('ui.ultimate').toUpperCase(),
                        style: nunito(13, color: Pal.goldLight, letterSpacing: 5),
                      ),
                      const SizedBox(height: 2),
                      _OutlinedText(_cutSkill, 34, Pal.cream,
                          align: isHero ? TextAlign.left : TextAlign.right),
                      const SizedBox(height: 4),
                      Text(s.t(unit.nameKey),
                          style: nunito(15, color: accent, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // --------------------------------------------------------------- result

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

/// Lilita text with a dark outline (damage numbers, skill names).
class _OutlinedText extends StatelessWidget {
  const _OutlinedText(this.text, this.size, this.fill,
      {this.align = TextAlign.center});

  final String text;
  final double size;
  final Color fill;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontFamily: 'LilitaOne',
            fontSize: size,
            height: 1.1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.22
              ..strokeJoin = StrokeJoin.round
              ..color = Pal.outline,
          ),
        ),
        Text(text, textAlign: align, style: lilita(size, color: fill)),
      ],
    );
  }
}

// ---------------------------------------------------------------- painters

Path _star4(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * 0.38;
    final a = -math.pi / 2 + i * math.pi / 4;
    final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  return p..close();
}

/// Impact bursts, slashes, projectiles and status effects for one event.
class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.kind,
    required this.t,
    required this.hitT,
    required this.from,
    required this.to,
    required this.ranged,
    required this.ult,
    required this.newAction,
    required this.rgb,
  });

  final EventKind kind;
  final double t;
  final double hitT;
  final Offset? from;
  final Offset? to;
  final bool ranged;
  final bool ult;
  final bool newAction;
  final int rgb;

  @override
  void paint(Canvas canvas, Size size) {
    final target = to;
    if (target == null) return;

    // Ultimate: white flash when the strike lands.
    if (ult && newAction) {
      final f = (1 - t / 0.35).clamp(0.0, 1.0);
      if (f > 0) {
        canvas.drawRect(Offset.zero & size, Paint()..color = _a(0xFFF3C0, 0.5 * f));
      }
    }

    switch (kind) {
      case EventKind.attack:
        final src = from;
        // Projectile for ranged attackers.
        if (ranged && src != null && src != target && t < hitT + 0.02) {
          final p = ((t - 0.03) / (hitT - 0.03)).clamp(0.0, 1.0);
          final pos = Offset.lerp(src, target, Curves.easeIn.transform(p))!;
          final tail = Offset.lerp(src, target, Curves.easeIn.transform((p - 0.25).clamp(0.0, 1.0)))!;
          canvas.drawLine(
              tail,
              pos,
              Paint()
                ..strokeCap = StrokeCap.round
                ..strokeWidth = ult ? 10 : 6
                ..color = _a(rgb, 1));
          canvas.drawCircle(pos, ult ? 13 : 8, Paint()..color = _a(0xFFFFFF, 0.95));
          canvas.drawCircle(pos, ult ? 22 : 14, Paint()..color = _a(rgb, 0.35));
        }
        if (t >= hitT) {
          final k = ((t - hitT) / 0.55).clamp(0.0, 1.0);
          final fade = 1 - k;
          final r = (ult ? 20.0 : 10.0) + k * (ult ? 78.0 : 44.0);
          canvas.drawCircle(
              target,
              r * 0.55,
              Paint()..color = _a(0xFFFFFF, 0.65 * fade));
          canvas.drawCircle(
              target,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (ult ? 9.0 : 5.0) * fade
                ..color = _a(rgb, fade));
          final rays = Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = ult ? 5 : 3
            ..color = _a(0xFFFFFF, fade);
          final n = ult ? 12 : 8;
          for (var i = 0; i < n; i++) {
            final a = i * 2 * math.pi / n + (ult ? 0.2 : 0);
            final d = Offset(math.cos(a), math.sin(a));
            canvas.drawLine(target + d * (r * 0.55), target + d * (r * 1.2), rays);
          }
          if (!ranged) {
            // Cross slash.
            final s1 = Paint()
              ..strokeCap = StrokeCap.round
              ..strokeWidth = ult ? 9 : 6
              ..color = _a(0xFFFFFF, fade);
            final len = (ult ? 54.0 : 34.0) * (0.5 + 0.5 * math.min(1.0, k * 4));
            canvas.drawLine(target + Offset(-len, -len), target + Offset(len, len), s1);
            canvas.drawLine(target + Offset(len, -len * 0.6), target + Offset(-len, len * 0.6), s1..strokeWidth = (ult ? 6 : 4));
          }
        }
      case EventKind.heal:
        final kh = t;
        canvas.drawCircle(
            target,
            26 + 26 * kh,
            Paint()..color = _a(0x7CF0B0, 0.35 * (1 - kh)));
        final plus = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5
          ..color = _a(0x7CF0B0, 1 - kh);
        for (var i = 0; i < 5; i++) {
          final c = target + Offset((i - 2) * 15.0, -12 - 54 * kh - (i.isOdd ? 12 : 0));
          canvas.drawLine(c + const Offset(-6, 0), c + const Offset(6, 0), plus);
          canvas.drawLine(c + const Offset(0, -6), c + const Offset(0, 6), plus);
        }
      case EventKind.stun || EventKind.skip:
        final top = target + const Offset(0, -64);
        for (var i = 0; i < 3; i++) {
          final a = t * 8 + i * 2 * math.pi / 3;
          final c = top + Offset(math.cos(a) * 20, math.sin(a) * 7);
          canvas.drawPath(_star4(c, 8), Paint()..color = _a(0xFFE08A, 0.95));
        }
      case EventKind.buff ||
            EventKind.shield ||
            EventKind.taunt ||
            EventKind.reflect ||
            EventKind.silence:
        final kb = t;
        final ringC = _a(rgb, 1 - kb);
        canvas.drawCircle(
            target,
            22 + 40 * kb,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * (1 - kb) + 1
              ..color = ringC);
        canvas.drawCircle(
            target, 14 + 22 * kb, Paint()..color = _a(rgb, 0.25 * (1 - kb)));
        if (kind == EventKind.buff) {
          for (var i = 0; i < 3; i++) {
            final pt = target + Offset((i - 1) * 18.0, -20 - 46 * kb);
            final p = Path()
              ..moveTo(pt.dx, pt.dy - 8)
              ..lineTo(pt.dx + 7, pt.dy + 4)
              ..lineTo(pt.dx - 7, pt.dy + 4)
              ..close();
            canvas.drawPath(p, Paint()..color = ringC);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) =>
      old.t != t ||
      old.kind != kind ||
      old.to != to ||
      old.from != from ||
      old.ult != ult;
}

/// Ultimate cut-in backdrop: rotating rays, a colored diagonal band, speed lines.
class _CutinPainter extends CustomPainter {
  _CutinPainter({
    required this.t,
    required this.env,
    required this.rgb,
    required this.fromLeft,
  });

  final double t;
  final double env;
  final int rgb;
  final bool fromLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(fromLeft ? w * 0.28 : w * 0.72, h * 0.5);

    // Rotating rays behind the figure.
    final rayPaint = Paint()..color = _a(0xFFE08A, 0.20 * env);
    for (var i = 0; i < 14; i++) {
      final a = t * 1.4 + i * 2 * math.pi / 14;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.07) * w * 1.3, c.dy + math.sin(a - 0.07) * w * 1.3)
        ..lineTo(c.dx + math.cos(a + 0.07) * w * 1.3, c.dy + math.sin(a + 0.07) * w * 1.3)
        ..close();
      canvas.drawPath(p, rayPaint);
    }

    // Diagonal band.
    final band = Path()
      ..moveTo(0, h * (fromLeft ? 0.34 : 0.28))
      ..lineTo(w, h * (fromLeft ? 0.26 : 0.34))
      ..lineTo(w, h * (fromLeft ? 0.66 : 0.74))
      ..lineTo(0, h * (fromLeft ? 0.74 : 0.66))
      ..close();
    canvas.drawPath(band, Paint()..color = _a(rgb, 0.30 * env));
    final edge = Paint()
      ..strokeWidth = 4
      ..color = _a(0xFFE08A, 0.9 * env);
    canvas.drawLine(Offset(0, h * (fromLeft ? 0.34 : 0.28)),
        Offset(w, h * (fromLeft ? 0.26 : 0.34)), edge);
    canvas.drawLine(Offset(0, h * (fromLeft ? 0.74 : 0.66)),
        Offset(w, h * (fromLeft ? 0.66 : 0.74)), edge);

    // Speed lines.
    final sp = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = _a(0xFFFFFF, 0.34 * env);
    for (var i = 0; i < 16; i++) {
      final y = h * (0.20 + (i * 0.0377) % 0.6);
      final len = 70.0 + (i * 53) % 110;
      final speed = 2.2 + (i % 4) * 0.5;
      var x = ((t * w * speed + i * 91) % (w + len));
      if (fromLeft) x = w - x;
      canvas.drawLine(Offset(x, y), Offset(x + (fromLeft ? len : -len), y), sp);
    }
  }

  @override
  bool shouldRepaint(_CutinPainter old) => old.t != t || old.env != env;
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
