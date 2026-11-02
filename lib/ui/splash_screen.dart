import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;

import '../game_content.dart';
import '../l10n/strings.dart';
import 'app_shell.dart';
import 'theme.dart';

/// Splash / loading screen (board: Splash.dc.html). Loads the game content,
/// shows the logo for at least a moment, then opens the app shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final Future<Strings> _strings = Strings.load();
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final loading = loadSession();
      await _progress.forward();
      final session = await loading;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => AppShell(session: session),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } on TickerCanceled {
      // Screen closed while loading: nothing to do.
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.62, 1],
            colors: [Pal.bg, Color(0xFF2A1F5E), Color(0xFF4A2F7A)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AspectRatio(
                aspectRatio: 390 / 360,
                child: CustomPaint(painter: _SkylinePainter()),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text('THEO',
                      style: cinzel(22, color: Pal.gold, letterSpacing: 16)
                          .copyWith(height: 1)),
                  const SizedBox(height: 6),
                  Text('MYTH', style: cinzel(84, weight: 900)),
                  const SizedBox(height: 6),
                  const _Divider(),
                  const SizedBox(height: 10),
                  FutureBuilder<Strings>(
                    future: _strings,
                    builder: (context, snap) => Text(
                      snap.data?.t('ui.idle_rpg') ?? 'IDLE RPG',
                      style: nunito(13, color: Pal.muted, letterSpacing: 8),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 56),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _progress,
                          builder: (context, _) => Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Pal.bg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progress.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Pal.gold,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<Strings>(
                          future: _strings,
                          builder: (context, snap) => Text(
                            _error != null
                                ? '$_error'
                                : (snap.data?.t('ui.splash_loading') ?? ''),
                            textAlign: TextAlign.center,
                            style: nunito(13, weight: 700, color: Pal.muted),
                          ),
                        ),
                      ],
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
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 210,
        height: 14,
        child: CustomPaint(painter: _DividerPainter()),
      );
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Pal.gold
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(0, 7), Offset(size.width / 2 - 13, 7), line);
    canvas.drawLine(
        Offset(size.width / 2 + 13, 7), Offset(size.width, 7), line);
    final c = size.width / 2;
    canvas.drawPath(
        Path()
          ..moveTo(c, 1)
          ..lineTo(c + 6, 7)
          ..lineTo(c, 13)
          ..lineTo(c - 6, 7)
          ..close(),
        Paint()..color = Pal.gold);
  }

  @override
  bool shouldRepaint(_DividerPainter old) => false;
}

/// Mountains, columns and a pale sun along the bottom (from the board).
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 390, size.height / 360);
    canvas.drawCircle(const Offset(195, 150), 70,
        Paint()..color = const Color(0x24F2C14E));
    canvas.drawPath(
        Path()
          ..moveTo(0, 360)
          ..lineTo(0, 190)
          ..lineTo(70, 120)
          ..lineTo(150, 230)
          ..lineTo(150, 360)
          ..close(),
        Paint()..color = const Color(0x384FB3E6));
    canvas.drawPath(
        Path()
          ..moveTo(90, 360)
          ..lineTo(170, 210)
          ..lineTo(250, 360)
          ..close(),
        Paint()..color = const Color(0x3812A596));
    final col = Paint()..color = const Color(0x4D2A6FDB);
    for (final x in [250.0, 284.0, 318.0, 352.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 190, 22, 170), col);
    }
    canvas.drawPath(
        Path()
          ..moveTo(240, 190)
          ..lineTo(384, 190)
          ..lineTo(312, 148)
          ..close(),
        col);
    canvas.drawRect(const Rect.fromLTWH(0, 300, 390, 60),
        Paint()..color = const Color(0x8C14122B));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => false;
}
