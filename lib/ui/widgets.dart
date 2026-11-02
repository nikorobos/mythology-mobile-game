import 'package:flutter/material.dart';

import '../core/models.dart';
import 'theme.dart';

/// Shared building blocks for the board-styled screens.

// ---------------------------------------------------------------- currency

enum _Glyph { coin, gem }

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph);

  final _Glyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    switch (glyph) {
      case _Glyph.coin:
        const edge = Color(0xFFB87A12);
        canvas.drawCircle(
            const Offset(12, 12), 10, Paint()..color = Pal.gold);
        canvas.drawCircle(
            const Offset(12, 12),
            10,
            Paint()
              ..color = edge
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawCircle(
            const Offset(12, 12),
            5.5,
            Paint()
              ..color = edge
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      case _Glyph.gem:
        final p = Path()
          ..moveTo(12, 3)
          ..lineTo(20, 10)
          ..lineTo(12, 21)
          ..lineTo(4, 10)
          ..close();
        canvas.drawPath(p, Paint()..color = Pal.gem);
        canvas.drawPath(
            p,
            Paint()
              ..color = const Color(0xFF1B7FA0)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeJoin = StrokeJoin.round);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph;
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
            size: Size(size, size), painter: _GlyphPainter(_Glyph.coin)),
      );
}

class GemIcon extends StatelessWidget {
  const GemIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
            size: Size(size, size), painter: _GlyphPainter(_Glyph.gem)),
      );
}

enum Currency { gold, gems }

/// Rounded pill with a currency icon and a value (board header).
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({
    super.key,
    required this.currency,
    required this.text,
    this.semanticLabel,
  });

  final Currency currency;
  final String text;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: Pal.panel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            currency == Currency.gold ? const CoinIcon() : const GemIcon(),
            const SizedBox(width: 6),
            Text(text, style: nunito(14)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- stars

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.count, this.total = 5, this.size = 13});

  final int count;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count / $total',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < total; i++)
              Padding(
                padding: EdgeInsets.only(right: i == total - 1 ? 0 : 2),
                child: Icon(Icons.star_rounded,
                    size: size, color: i < count ? Pal.gold : Pal.track2),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- roles

IconData roleIcon(Role r) => switch (r) {
      Role.tank => Icons.shield_outlined,
      Role.dps => Icons.bolt,
      Role.healer => Icons.add,
      Role.support => Icons.auto_awesome,
    };

/// Small round role badge (hero grid).
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.size = 26});

  final Role role;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: roleColor(role), shape: BoxShape.circle),
      child: Icon(roleIcon(role), size: size * 0.6, color: Pal.bg),
    );
  }
}

/// Role pill with text, e.g. "TANK · MELEE".
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, required this.text});

  final Role role;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: roleColor(role),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: nunito(12, color: Pal.bg, letterSpacing: 1.5)),
    );
  }
}

// ----------------------------------------------------------- hero portraits

const _skins = [
  Color(0xFFD79A63),
  Color(0xFFE2B07E),
  Color(0xFFE8B88A),
  Color(0xFFD9A878),
  Color(0xFFE3B58C),
  Color(0xFFD9AE86),
];
const _hairs = [
  Color(0xFFE0A33A),
  Color(0xFF7A4A25),
  Color(0xFF3E2412),
  Color(0xFF1E1630),
  Color(0xFFE8C25A),
  Color(0xFFCFCFCF),
];

int _seedOf(String id) =>
    id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);

class _BustPainter extends CustomPainter {
  _BustPainter(this.seed, this.cloth);

  final int seed;
  final Color cloth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final skin = _skins[seed % _skins.length];
    final hair = _hairs[(seed ~/ 7) % _hairs.length];
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = Pal.outline;
    void shape(Path p, Color c) {
      canvas.drawPath(p, Paint()..color = c);
      canvas.drawPath(p, line);
    }

    shape(
        Path()
          ..moveTo(12, 100)
          ..quadraticBezierTo(14, 72, 50, 70)
          ..quadraticBezierTo(86, 72, 88, 100)
          ..close(),
        cloth);
    shape(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(50, 46), radius: 22)),
        skin);
    shape(
        Path()
          ..moveTo(27, 46)
          ..quadraticBezierTo(25, 14, 50, 12)
          ..quadraticBezierTo(75, 14, 73, 46)
          ..quadraticBezierTo(62, 30, 50, 30)
          ..quadraticBezierTo(38, 30, 27, 46)
          ..close(),
        hair);
    final eye = Paint()..color = Pal.outline;
    canvas.drawCircle(const Offset(42, 48), 2.6, eye);
    canvas.drawCircle(const Offset(58, 48), 2.6, eye);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BustPainter old) =>
      old.seed != seed || old.cloth != cloth;
}

/// PLACEHOLDER art: a generic bust (colors vary per unit id) until real
/// hero art exists. Replace this widget with the real portrait later.
class HeroBust extends StatelessWidget {
  const HeroBust({super.key, required this.unit, this.size = 60});

  final Unit unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cloth = mythColors(unit.mythology).$1;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size),
        painter: _BustPainter(_seedOf(unit.id), cloth),
      ),
    );
  }
}

/// Square portrait: dark mythology fill + role-colored border (squad strip,
/// ultimate buttons).
class PortraitSquare extends StatelessWidget {
  const PortraitSquare({
    super.key,
    required this.unit,
    this.size = 60,
    this.dimmed = false,
  });

  final Unit unit;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final fill = mythColors(unit.mythology).$2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: roleColor(unit.role), width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: HeroBust(unit: unit, size: size * 0.92),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- progress

class Bar extends StatelessWidget {
  const Bar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.track = Pal.track,
  });

  final double value;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- buttons

/// Chunky gold button (BATTLE, LEVEL UP, SUMMON x10).
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sub,
    this.height = 58,
    this.fontSize = 20,
    this.letterSpacing,
    this.depth = 4,
  });

  final String label;
  final Widget? sub;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final double? letterSpacing;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Pal.goldLight, Pal.goldDark],
          ),
          boxShadow: [
            BoxShadow(color: Pal.goldShadow, offset: Offset(0, depth)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: lilita(fontSize,
                          color: Pal.ink, letterSpacing: letterSpacing)),
                  if (sub != null) sub!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark button with gold border (STAR UP, SUMMON x1).
class DarkButton extends StatelessWidget {
  const DarkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sub,
    this.height = 58,
    this.fontSize = 20,
    this.borderColor = Pal.gold,
  });

  final String label;
  final Widget? sub;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Pal.track,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: const [BoxShadow(color: Pal.bg, offset: Offset(0, 4))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: lilita(fontSize)),
                  if (sub != null) sub!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small square icon button (back, filters). Always >= 44 px.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Pal.cream,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: selected ? Pal.track2 : Pal.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- navigation

class NavItem {
  const NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// The one bottom nav shared by Home, Heroes and Summon.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Pal.panel,
      padding: EdgeInsets.fromLTRB(
          8, 6, 8, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: items[i].label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].icon,
                            size: 26,
                            color: i == index ? Pal.gold : Pal.muted),
                        const SizedBox(height: 3),
                        Text(items[i].label,
                            style: nunito(12,
                                color: i == index ? Pal.gold : Pal.muted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Screen title row used on the tab screens (Heroes, Summon).
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: lilita(30)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small gold uppercase section label ("YOUR SQUAD").
class GoldLabel extends StatelessWidget {
  const GoldLabel(this.text, {super.key, this.color = Pal.gold});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: labelStyle(color: color));
}
