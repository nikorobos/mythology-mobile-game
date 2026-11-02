import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/player.dart';
import '../game_content.dart';
import '../l10n/strings.dart';
import 'theme.dart';
import 'widgets.dart';

/// Summon tab (board: Summon.dc.html): summoning circle, pity bar, x1 / x10.
/// Not built (no such system yet): banner tabs, rate-up, free ad summon.
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
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final st = player.state;
          final left = (eco.pityEpic - st.pity).clamp(1, eco.pityEpic).toInt();
          return Column(
            children: [
              TabHeader(
                title: s.t('ui.summon'),
                trailing: CurrencyPill(
                    currency: Currency.gems,
                    text: formatNumber(st.gems),
                    semanticLabel: s.t('ui.gems')),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _banner(s),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                              '${s.t('ui.pity')} $left ${s.t('ui.pulls')}',
                              style: nunito(13)),
                        ),
                        Text('${st.pity} / ${eco.pityEpic}',
                            style: nunito(13, color: Pal.muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Bar(value: st.pity / eco.pityEpic, color: Pal.gold),
                    if (_failed) ...[
                      const SizedBox(height: 10),
                      Text(s.t('ui.not_enough_gems'),
                          textAlign: TextAlign.center,
                          style: nunito(14, color: Pal.gold)),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _pullButton(1, dark: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _pullButton(10, dark: false)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pullButton(int count, {required bool dark}) {
    final s = widget.session.content.strings;
    final cost = widget.session.content.economy.summonCost(count);
    final label = s.t(count == 1 ? 'ui.summon_x1' : 'ui.summon_x10').toUpperCase();
    final sub = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GemIcon(size: 14),
        const SizedBox(width: 5),
        Text(formatNumber(cost),
            style: nunito(13, color: dark ? Pal.cream : Pal.ink)),
      ],
    );
    return dark
        ? DarkButton(
            label: label, sub: sub, height: 66, fontSize: 21,
            onPressed: () => _pull(1))
        : GoldButton(
            label: label, sub: sub, height: 66, fontSize: 21,
            onPressed: () => _pull(count));
  }

  Widget _banner(Strings s) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 330,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _CirclePainter())),
            if (_last.isEmpty) ...[
              const Center(
                child: Icon(Icons.auto_awesome, color: Pal.goldLight, size: 84),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(s.t('ui.summon_title'),
                    textAlign: TextAlign.center,
                    style: lilita(22, shadows: const [
                      Shadow(color: Color(0xCC1B1030), offset: Offset(0, 2))
                    ])),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoldLabel(s.t('ui.summon_results')),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 10,
                          children: [for (final r in _last) _result(r)],
                        ),
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

  Widget _result(SummonResult r) {
    final c = widget.session.content;
    final s = c.strings;
    final hero = c.heroes.firstWhere((h) => h.id == r.heroId);
    final color = rarityColor(hero.rarity);
    return SizedBox(
      width: 62,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: mythColors(hero.mythology).$2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: HeroBust(unit: hero, size: 56),
                ),
              ),
              if (r.isNew)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Pal.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(s.t('ui.new'), style: nunito(10, color: Pal.ink)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(s.t(hero.nameKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nunito(11, shadows: true)),
          Text(
            r.isNew ? s.t('rarity.${hero.rarity.name}') : '+${r.shardsGained}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nunito(10, weight: 700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Purple glow, light rays and a gold summoning circle (from the board).
class _CirclePainter extends CustomPainter {
  const _CirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 358, size.height / 330);
    const rect = Rect.fromLTWH(0, 0, 358, 330);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.1),
            radius: 0.7,
            colors: [Color(0xFF6B43B8), Color(0xFF2A1F5E), Color(0xFF14122B)],
            stops: [0, 0.6, 1],
          ).createShader(rect));
    final ray = Path()
      ..moveTo(179, 150)
      ..lineTo(168, -40)
      ..lineTo(190, -40)
      ..close();
    final rayPaint = Paint()..color = const Color(0x21FFE08A);
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(179, 150);
      canvas.rotate(i * math.pi / 6);
      canvas.translate(-179, -150);
      canvas.drawPath(ray, rayPaint);
      canvas.restore();
    }
    Paint ring(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = c;
    canvas.drawOval(Rect.fromCenter(center: const Offset(179, 262), width: 280, height: 76),
        ring(3, Pal.gold));
    canvas.drawOval(Rect.fromCenter(center: const Offset(179, 262), width: 208, height: 54),
        ring(2, const Color(0xB3F2C14E)));
    canvas.drawOval(Rect.fromCenter(center: const Offset(179, 262), width: 132, height: 34),
        Paint()..color = const Color(0x2EFFE08A));
    final dot = Paint()..color = Pal.gold;
    for (final p in const [
      Offset(319, 262), Offset(278, 289), Offset(179, 300), Offset(80, 289),
      Offset(39, 262), Offset(80, 235), Offset(179, 224), Offset(278, 235),
    ]) {
      canvas.drawCircle(p, 4, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CirclePainter old) => false;
}
