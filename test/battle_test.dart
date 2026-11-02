import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theomyth/core/battle.dart';
import 'package:theomyth/core/content.dart';
import 'package:theomyth/core/models.dart';

void main() {
  final heroes = parseUnits(File('assets/data/heroes.json').readAsStringSync());
  final monsters =
      parseUnits(File('assets/data/monsters.json').readAsStringSync());

  test('content parses into units', () {
    expect(heroes.length, 3);
    expect(monsters.every((m) => m.ai), isTrue);
    expect(heroes.first.role, Role.tank);
  });

  test('every nameKey exists in both languages', () {
    final en = parseStrings(File('assets/i18n/en.json').readAsStringSync());
    final el = parseStrings(File('assets/i18n/el.json').readAsStringSync());
    for (final u in [...heroes, ...monsters]) {
      expect(en.containsKey(u.nameKey), isTrue, reason: u.nameKey);
      expect(el.containsKey(u.nameKey), isTrue, reason: u.nameKey);
      for (final s in u.skills) {
        expect(en.containsKey(s.nameKey), isTrue, reason: s.nameKey);
        expect(el.containsKey(s.nameKey), isTrue, reason: s.nameKey);
      }
    }
  });

  test('damage is at least 1', () {
    expect(calcDamage(1, 1000), 1);
    expect(calcDamage(100, 40), 80);
  });

  test('battle is deterministic and ends', () {
    final a = simulateBattle(heroes, monsters);
    final b = simulateBattle(heroes, monsters);
    expect(a.log, b.log);
    expect(a.winner, isNotNull);
  });

  test('stronger side wins', () {
    final r = simulateBattle(heroes, [monsters[1]]);
    expect(r.winner, Side.heroes);
  });
}
