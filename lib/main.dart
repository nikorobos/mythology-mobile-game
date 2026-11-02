import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'core/content.dart';
import 'core/models.dart';
import 'l10n/strings.dart';
import 'ui/battle_screen.dart';

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

class _Content {
  const _Content(this.heroes, this.monsters, this.strings);

  final List<Unit> heroes;
  final List<Unit> monsters;
  final Strings strings;
}

Future<_Content> _loadContent() async {
  final heroes = parseUnits(await rootBundle.loadString('assets/data/heroes.json'));
  final monsters =
      parseUnits(await rootBundle.loadString('assets/data/monsters.json'));
  final strings = await Strings.load();
  return _Content(heroes, monsters, strings);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<_Content> _content = _loadContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder<_Content>(
          future: _content,
          builder: (context, snap) {
            final c = snap.data;
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
                    onPressed: c == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => BattleScreen(
                                heroes: c.heroes,
                                enemies: c.monsters,
                                strings: c.strings,
                              ),
                            )),
                    child: Text(c?.strings.t('ui.battle') ?? '...'),
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
