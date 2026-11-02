import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart' show rootBundle;

import '../core/content.dart';

/// Minimal string table (English + Greek). Missing keys show the key itself.
class Strings {
  Strings(this._map);

  final Map<String, String> _map;

  String t(String key) => _map[key] ?? key;

  static Future<Strings> load([String? languageCode]) async {
    final code =
        languageCode ?? PlatformDispatcher.instance.locale.languageCode;
    final file = code == 'el' ? 'el' : 'en';
    final text = await rootBundle.loadString('assets/i18n/$file.json');
    return Strings(parseStrings(text));
  }
}
