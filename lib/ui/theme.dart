import 'package:flutter/material.dart';

import '../core/models.dart';

/// Shared visual identity (reference.md "Visual identity").
class Pal {
  Pal._();

  static const bg = Color(0xFF14122B);
  static const panel = Color(0xFF1D1A3D);
  static const panel2 = Color(0xFF252248);
  static const track = Color(0xFF2A2650);
  static const track2 = Color(0xFF3C3868);
  static const dim = Color(0xFF4A4575);
  static const gold = Color(0xFFF2C14E);
  static const goldLight = Color(0xFFFFE08A);
  static const goldDark = Color(0xFFF29E1C);
  static const goldShadow = Color(0xFFA8650B);
  static const cream = Color(0xFFF3EEDC);
  static const muted = Color(0xFFB9B4D6);
  static const soft = Color(0xFFC4BFE0);
  static const outline = Color(0xFF1B1030);
  static const ink = Color(0xFF2A0F4A);
  static const green = Color(0xFF5FD38D);
  static const red = Color(0xFFFF6B5B);
  static const gem = Color(0xFF5BE0FF);

  // Translucent helpers (const, so no deprecated Color APIs are needed).
  static const scrim = Color(0xCC14122B); // bg at 80%
  static const scrimStrong = Color(0xD914122B); // bg at 85%
  static const shadowSoft = Color(0x66000000);
}

Color roleColor(Role r) => switch (r) {
      Role.tank => const Color(0xFF6FA8FF),
      Role.dps => const Color(0xFFFF8A5C),
      Role.healer => const Color(0xFF5FD38D),
      Role.support => const Color(0xFFC79BFF),
    };

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9AA3B2),
      Rarity.rare => const Color(0xFF4FB3E6),
      Rarity.epic => const Color(0xFFB07CFF),
      Rarity.legendary => const Color(0xFFF2C14E),
    };

/// Two gradient colors for a mythology tag. Unknown tags use the
/// cross-myth purple, so new mythologies never crash the UI.
(Color, Color) mythColors(String myth) => switch (myth) {
      'greek' => (const Color(0xFF2A6FDB), const Color(0xFF1D3F96)),
      'norse' => (const Color(0xFF2E8FC4), const Color(0xFF2A6A9E)),
      'egyptian' => (const Color(0xFFC98A38), const Color(0xFF8A5A1E)),
      _ => (const Color(0xFF6B43B8), const Color(0xFF2A1F5E)),
    };

/// Lighter accent for labels on a mythology (chip text, etc.).
Color mythAccent(String myth) => switch (myth) {
      'greek' => const Color(0xFF4F8BFF),
      'norse' => const Color(0xFF4FB3E6),
      'egyptian' => const Color(0xFFE0A33A),
      _ => const Color(0xFFB07CFF),
    };

FontWeight _fw(int w) => FontWeight.values[(w ~/ 100).clamp(1, 9) - 1];

/// Headings, buttons, names. (No Greek glyphs in this font: Greek text
/// falls back to the system font.)
TextStyle lilita(double size,
        {Color color = Pal.cream,
        double? letterSpacing,
        List<Shadow>? shadows}) =>
    TextStyle(
      fontFamily: 'LilitaOne',
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.1,
      shadows: shadows,
    );

/// Body and labels. Variable font: [weight] 200-1000 via the wght axis.
TextStyle nunito(double size,
        {int weight = 800, Color color = Pal.cream, double? letterSpacing}) =>
    TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: _fw(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );

/// Logo only.
TextStyle cinzel(double size,
        {int weight = 700, Color color = Pal.cream, double? letterSpacing}) =>
    TextStyle(
      fontFamily: 'CinzelDecorative',
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: weight >= 900 ? FontWeight.w900 : FontWeight.w700,
      height: 1.05,
    );

/// Small gold label used for section headings ("YOUR SQUAD", "SKILLS").
TextStyle labelStyle({Color color = Pal.gold}) =>
    nunito(12, weight: 800, color: color, letterSpacing: 2.5);

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: const ColorScheme.dark(
      primary: Pal.gold,
      onPrimary: Pal.bg,
      surface: Pal.panel,
      onSurface: Pal.cream,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: Pal.cream,
      displayColor: Pal.cream,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerColor: Pal.track,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Pal.bg,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
