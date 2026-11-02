import 'dart:convert';

import 'economy.dart';
import 'models.dart';
import 'stages.dart';

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

/// Parses the endless-stage settings (assets/data/stages.json).
StageConfig parseStageConfig(String jsonText) =>
    StageConfig.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);

Economy parseEconomy(String jsonText) =>
    Economy.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);
