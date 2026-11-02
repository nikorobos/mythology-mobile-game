// Pure Dart. Endless stages: any stage number n >= 1 is built from a few
// growth settings and a looping list of myth chapters, so the game never
// runs out of content. Deterministic.

import 'dart:math' show min, pow;

import 'models.dart';

/// One chapter = one myth event, played over [StageConfig.bossEvery] stages
/// and ending with a boss. Texts live in the string tables:
/// chapter.<id>.title and chapter.<id>.intro.
class ChapterDef {
  const ChapterDef({
    required this.id,
    required this.mythology,
    required this.pool,
    required this.boss,
  });

  final String id;
  final String mythology;

  /// Monster ids used on normal stages of this chapter.
  final List<String> pool;

  /// Monster id of the chapter boss.
  final String boss;

  String get titleKey => 'chapter.$id.title';
  String get introKey => 'chapter.$id.intro';

  factory ChapterDef.fromJson(Map<String, dynamic> j) => ChapterDef(
        id: j['id'] as String,
        mythology: j['mythology'] as String,
        pool: List<String>.from(j['pool'] as List),
        boss: j['boss'] as String,
      );
}

class StageConfig {
  const StageConfig({
    required this.chapters,
    this.bossEvery = 10,
    this.minSize = 2,
    this.maxSize = 5,
    this.growEveryStages = 2,
    this.hpGrowth = 1.08,
    this.atkGrowth = 1.06,
    this.bossHpMult = 3.0,
    this.bossAtkMult = 1.3,
  });

  /// Chapters loop forever: chapter 4 reuses chapter 1's myth with stronger
  /// enemies (growth keeps compounding).
  final List<ChapterDef> chapters;
  final int bossEvery;
  final int minSize;
  final int maxSize;

  /// Enemy count grows by one every this many stages, from minSize to maxSize.
  final int growEveryStages;

  /// Per-stage multipliers, compounding: stat * growth^(stage - 1).
  final double hpGrowth;
  final double atkGrowth;
  final double bossHpMult;
  final double bossAtkMult;

  factory StageConfig.fromJson(Map<String, dynamic> j) => StageConfig(
        chapters: [
          for (final c in j['chapters'] as List)
            ChapterDef.fromJson(c as Map<String, dynamic>)
        ],
        bossEvery: (j['bossEvery'] as int?) ?? 10,
        minSize: (j['minSize'] as int?) ?? 2,
        maxSize: (j['maxSize'] as int?) ?? 5,
        growEveryStages: (j['growEveryStages'] as int?) ?? 2,
        hpGrowth: (j['hpGrowth'] as num?)?.toDouble() ?? 1.08,
        atkGrowth: (j['atkGrowth'] as num?)?.toDouble() ?? 1.06,
        bossHpMult: (j['bossHpMult'] as num?)?.toDouble() ?? 3.0,
        bossAtkMult: (j['bossAtkMult'] as num?)?.toDouble() ?? 1.3,
      );
}

bool isBossStage(int stage, StageConfig c) => stage % c.bossEvery == 0;

/// Chapter number, 1-based and unbounded: stages 1..bossEvery = chapter 1.
int chapterNumber(int stage, StageConfig c) => (stage - 1) ~/ c.bossEvery + 1;

/// The myth chapter played at [stage] (loops through the list).
ChapterDef chapterAt(int stage, StageConfig c) =>
    c.chapters[(chapterNumber(stage, c) - 1) % c.chapters.length];

double _growth(double rate, int stage) =>
    min(pow(rate, stage - 1).toDouble(), 1e9);

/// Enemy team for [stage] (1-based).
List<Unit> buildStage(int stage, List<Unit> monsters, StageConfig c) {
  if (stage < 1) throw ArgumentError.value(stage, 'stage', 'must be >= 1');
  Unit byId(String id) => monsters.firstWhere((m) => m.id == id);
  final chapter = chapterAt(stage, c);
  final hp = _growth(c.hpGrowth, stage);
  final atk = _growth(c.atkGrowth, stage);

  if (isBossStage(stage, c)) {
    return [
      byId(chapter.boss).scaled(hp: hp * c.bossHpMult, atk: atk * c.bossAtkMult),
      for (var i = 0; i < c.maxSize - 1; i++)
        byId(chapter.pool[(stage - 1 + i) % chapter.pool.length])
            .scaled(hp: hp, atk: atk),
    ];
  }

  final size = min(c.maxSize, c.minSize + (stage - 1) ~/ c.growEveryStages);
  return [
    for (var i = 0; i < size; i++)
      byId(chapter.pool[(stage - 1 + i) % chapter.pool.length])
          .scaled(hp: hp, atk: atk),
  ];
}
