import '../core/models.dart';

/// Which units have board-style SVG art in assets/art. Units without art fall
/// back to the generic placeholder painters in widgets.dart.
const _heroArt = {
  'heracles', 'achilles', 'artemis', 'asclepius', 'athena', //
  'tyr', 'thor', 'skadi', 'freya', 'odin',
  'sobek', 'sekhmet', 'horus', 'isis', 'thoth',
};

const _monsterArt = {
  'minotaur', 'fenrir', 'ammit', 'cerberus_duat', 'frost_sphinx',
  'shadow_jackal', 'cerberus', 'chimera', 'medusa', 'erinys', 'sea_serpent',
  'titan', 'giant', 'cronus', 'penthesilea', 'memnon', 'hector',
};

/// Asset path of a unit's 240x320 (3:4) full-body SVG, or null if it has none.
String? artAssetFor(Unit u) {
  if (u.ai) {
    return _monsterArt.contains(u.id) ? 'assets/art/monsters/${u.id}.svg' : null;
  }
  return _heroArt.contains(u.id) ? 'assets/art/heroes/${u.id}.svg' : null;
}
