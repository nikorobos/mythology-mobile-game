// Pure Dart. No Flutter imports: this file must stay unit-testable.

enum Role { tank, dps, healer, support }

enum Range { melee, ranged }

enum Rarity { common, rare, epic, legendary }

enum SkillType {
  none,
  damageMulti,
  damageAll,
  heal,
  healAll,
  taunt,
  stun,
  buffAtk,
  shield,
  reflect,
  silence,
}

T _enumByName<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((v) => v.name == name,
        orElse: () => throw FormatException('Unknown value "$name" for $T'));

SkillType _skillType(String? name) => switch (name) {
      null => SkillType.none,
      'damage_multi' => SkillType.damageMulti,
      'damage_all' => SkillType.damageAll,
      'heal' => SkillType.heal,
      'heal_all' => SkillType.healAll,
      'taunt' => SkillType.taunt,
      'stun' => SkillType.stun,
      'buff_atk' => SkillType.buffAtk,
      'shield' => SkillType.shield,
      'reflect' => SkillType.reflect,
      'silence' => SkillType.silence,
      _ => throw FormatException('Unknown skill type "$name"'),
    };

class Stats {
  const Stats({
    required this.hp,
    required this.atk,
    required this.def,
    required this.spd,
  });

  final int hp;
  final int atk;
  final int def;
  final int spd;

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        hp: json['hp'] as int,
        atk: json['atk'] as int,
        def: json['def'] as int,
        spd: json['spd'] as int,
      );
}

/// Data-driven skill. Meaning of [power] depends on [type]:
/// damageMulti = ATK multiplier per hit, heal = fraction of target max HP,
/// buffAtk = ATK bonus fraction, shield = fraction of max HP absorbed,
/// reflect = fraction of damage taken sent back. [duration] is in turns.
class Skill {
  const Skill({
    required this.id,
    required this.nameKey,
    required this.descKey,
    this.type = SkillType.none,
    this.power = 1.0,
    this.hits = 1,
    this.duration = 1,
    this.cooldown = 3,
  });

  final String id;
  final String nameKey;
  final String descKey;
  final SkillType type;
  final double power;
  final int hits;
  final int duration;
  final int cooldown;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as String,
        nameKey: json['nameKey'] as String,
        descKey: json['descKey'] as String,
        type: _skillType(json['type'] as String?),
        power: (json['power'] as num?)?.toDouble() ?? 1.0,
        hits: (json['hits'] as int?) ?? 1,
        duration: (json['duration'] as int?) ?? 1,
        cooldown: (json['cooldown'] as int?) ?? 3,
      );
}

/// Shared schema for heroes and monsters. A monster is a Unit with [ai] true.
/// Mythology is a tag, never a hardcoded enum: more mythologies come later.
class Unit {
  const Unit({
    required this.id,
    required this.nameKey,
    required this.mythology,
    required this.tags,
    required this.role,
    required this.range,
    required this.rarity,
    required this.baseStats,
    required this.skills,
    this.ultimate,
    this.ai = false,
  });

  final String id;
  final String nameKey;
  final String mythology;
  final List<String> tags;
  final Role role;
  final Range range;
  final Rarity rarity;
  final Stats baseStats;
  final List<Skill> skills;

  /// Cast when energy is full (tap, or automatically in AUTO mode).
  final Skill? ultimate;
  final bool ai;

  /// Copy with scaled HP and ATK (used for stage difficulty).
  Unit scaled({double hp = 1.0, double atk = 1.0}) => Unit(
        id: id,
        nameKey: nameKey,
        mythology: mythology,
        tags: tags,
        role: role,
        range: range,
        rarity: rarity,
        baseStats: Stats(
          hp: (baseStats.hp * hp).round(),
          atk: (baseStats.atk * atk).round(),
          def: baseStats.def,
          spd: baseStats.spd,
        ),
        skills: skills,
        ultimate: ultimate,
        ai: ai,
      );

  /// Copy with equipment bonuses: HP and ATK are multiplied, DEF and SPD
  /// are added (never below 0).
  Unit withBonus({
    double hpMult = 1.0,
    double atkMult = 1.0,
    int def = 0,
    int spd = 0,
  }) =>
      Unit(
        id: id,
        nameKey: nameKey,
        mythology: mythology,
        tags: tags,
        role: role,
        range: range,
        rarity: rarity,
        baseStats: Stats(
          hp: (baseStats.hp * hpMult).round(),
          atk: (baseStats.atk * atkMult).round(),
          def: baseStats.def + def < 0 ? 0 : baseStats.def + def,
          spd: baseStats.spd + spd < 0 ? 0 : baseStats.spd + spd,
        ),
        skills: skills,
        ultimate: ultimate,
        ai: ai,
      );

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id'] as String,
        nameKey: json['nameKey'] as String,
        mythology: json['mythology'] as String,
        tags: List<String>.from(json['tags'] as List),
        role: _enumByName(Role.values, json['role'] as String),
        range: _enumByName(Range.values, json['range'] as String),
        rarity: _enumByName(Rarity.values, json['rarity'] as String),
        baseStats: Stats.fromJson(json['baseStats'] as Map<String, dynamic>),
        skills: [
          for (final s in json['skills'] as List)
            Skill.fromJson(s as Map<String, dynamic>)
        ],
        ultimate: json['ultimate'] == null
            ? null
            : Skill.fromJson(json['ultimate'] as Map<String, dynamic>),
        ai: (json['ai'] as bool?) ?? false,
      );
}
