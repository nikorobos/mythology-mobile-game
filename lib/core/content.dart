import 'dart:convert';

import 'models.dart';

/// Parses a JSON document of the form {"units": [ ... ]}.
/// Pure Dart: the Flutter layer loads the asset string and passes it here.
List<Unit> parseUnits(String jsonText) {
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  return [
    for (final u in root['units'] as List) Unit.fromJson(u as Map<String, dynamic>)
  ];
}

/// Flat string table: {"key": "text"}.
Map<String, String> parseStrings(String jsonText) {
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  return root.map((k, v) => MapEntry(k, v as String));
}

/// Parses {"stages": [ ... ]}.
List<StageDef> parseStages(String jsonText) {
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  return [
    for (final s in root['stages'] as List)
      StageDef.fromJson(s as Map<String, dynamic>)
  ];
}
