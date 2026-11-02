# Theomyth: Idle RPG

Idle / auto-battler hero collector with Greek, Norse and Egyptian mythology. Android first, iOS later. Flutter + Flame.

## Layout
- `lib/core/` pure Dart (models, content parsing, battle simulation). No Flutter imports, unit-tested.
- `lib/main.dart` Flutter entry point (placeholder screen).
- `assets/data/` game content as JSON (placeholder stats).
- `assets/i18n/` English and Greek string tables. Every `nameKey`/`descKey` must exist in both.
- `test/` unit tests.

## First-time setup
The platform folders are not generated yet. With Flutter installed, from the repo root:

```
flutter create . --project-name theomyth --org com.houxe --platforms android
flutter pub get
flutter test
```

`flutter create .` keeps existing files (pubspec, lib/main.dart) only if you answer to keep them; review `git diff` afterwards. The `com.houxe` org is an assumption, change it before first Play upload (application ID cannot change later).

## Notes
- All stats and numbers are placeholders.
- Original designs only. Design board and rules live in the Claude Project "TheoMyth - App".
