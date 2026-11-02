import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../game_content.dart';
import 'theme.dart';
import 'widgets.dart';

/// "2h 14m" from minutes.
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// Idle rewards strip (board: Home). Gold that piled up while away, with
/// Collect and Collect x2 (the ad service is still a PLACEHOLDER).
class IdlePanel extends StatefulWidget {
  const IdlePanel({super.key, required this.session});

  final Session session;

  @override
  State<IdlePanel> createState() => _IdlePanelState();
}

class _IdlePanelState extends State<IdlePanel> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Refresh the shown amount while the screen is open.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _collectWithAd() async {
    setState(() => _busy = true);
    final earned = await widget.session.ads.showRewarded();
    if (earned && mounted) {
      widget.session.player.collectIdle(
          multiplier: widget.session.content.economy.adMultiplier);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.session.player;
    final eco = widget.session.content.economy;
    final s = widget.session.content.strings;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final pending = player.pendingIdle();
        final cap = player.maxIdleGold;
        final full = pending >= cap;
        final last = player.state.lastCollectMs ?? player.nowMs;
        final away = ((player.nowMs - last) ~/ 60000).clamp(0, eco.maxIdleMinutes);
        final canCollect = pending > 0 && !_busy;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: Pal.panel,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GoldLabel(s.t('ui.idle')),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const CoinIcon(size: 20),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '+${formatNumber(pending)}'
                                '${full ? '  ${s.t('ui.idle_full')}' : ''}',
                                overflow: TextOverflow.ellipsis,
                                style: nunito(18),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${formatMinutes(away)} / ${formatMinutes(eco.maxIdleMinutes)}',
                          style: nunito(12, weight: 700, color: Pal.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GreenButton(
                    label: s.t('ui.collect'),
                    onPressed: canCollect ? () => player.collectIdle() : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Bar(
                value: cap > 0 ? pending / cap : 0,
                color: Pal.gold,
                height: 6,
                track: Pal.track,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Pal.cream,
                    side: const BorderSide(color: Pal.green, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: canCollect ? _collectWithAd : null,
                  icon: const Icon(Icons.play_circle_fill,
                      color: Pal.green, size: 22),
                  label: Text(s.t('ui.collect_ad'), style: nunito(13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GreenButton extends StatelessWidget {
  const _GreenButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: Pal.green,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(label, style: nunito(14, color: Pal.bg)),
          ),
        ),
      ),
    );
  }
}
