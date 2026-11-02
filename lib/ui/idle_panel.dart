import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../game_content.dart';

const _bg = Color(0xFF14122B);
const _panel = Color(0xFF1D1A3D);
const _gold = Color(0xFFF2C14E);
const _cream = Color(0xFFF3EEDC);
const _muted = Color(0xFFB9B4D6);

/// Shows gold that piled up while away, with Collect and Collect x2 (ad).
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
    final s = widget.session.content.strings;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final pending = player.pendingIdle();
        final cap = player.maxIdleGold;
        final full = pending >= cap;
        return Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.t('ui.idle'),
                  style: const TextStyle(
                      color: _gold, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '+${formatNumber(pending)} ${s.t('ui.gold')}'
                '${full ? '   ${s.t('ui.idle_full')}' : ''}',
                style: const TextStyle(
                    color: _cream, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: cap > 0 ? (pending / cap).clamp(0.0, 1.0) : 0,
                  minHeight: 6,
                  color: _gold,
                  backgroundColor: const Color(0xFF3A3466),
                ),
              ),
              const SizedBox(height: 4),
              Text('max ${formatNumber(cap)}',
                  style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _gold, foregroundColor: _bg),
                      onPressed: pending > 0 && !_busy
                          ? () => player.collectIdle()
                          : null,
                      child: Text(s.t('ui.collect')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          pending > 0 && !_busy ? _collectWithAd : null,
                      child: Text(s.t('ui.collect_ad'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
