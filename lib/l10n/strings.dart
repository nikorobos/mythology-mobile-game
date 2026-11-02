import 'package:flutter/services.dart' show rootBundle;

import '../core/content.dart';

/// Minimal string table. English is ALWAYS the default (the device language
/// is ignored for now). The Greek table (assets/i18n/el.json) is kept in sync
/// and can be switched on later by passing languageCode 'el'.
/// Missing keys show the key itself.
class Strings {
  Strings(this._map);

  final Map<String, String> _map;

  String t(String key) => _map[key] ?? key;

  static Future<Strings> load([String languageCode = 'en']) async {
    final file = languageCode == 'el' ? 'el' : 'en';
    final text = await rootBundle.loadString('assets/i18n/$file.json');
    return Strings(parseStrings(text));
  }
}
