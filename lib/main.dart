import 'package:flutter/material.dart';

import 'game_content.dart';
import 'ui/squad_screen.dart';
import 'ui/summon_screen.dart';

void main() => runApp(const TheomythApp());

class TheomythApp extends StatelessWidget {
  const TheomythApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theomyth: Idle RPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14122B),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFF2C14E)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Session> _session = loadSession();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder<Session>(
          future: _session,
          builder: (context, snap) {
            final session = snap.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'THEOMYTH',
                  style: TextStyle(
                    color: Color(0xFFF3EEDC),
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 220,
                  height: 52,
                  child: FilledButton(
                    onPressed: session == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SquadScreen(session: session),
                            )),
                    child: Text(session?.content.strings.t('ui.battle') ?? '...'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: session == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SummonScreen(session: session),
                            )),
                    child:
                        Text(session?.content.strings.t('ui.summon') ?? '...'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
