import 'package:flutter/material.dart';

/// Central palette + Material 3 theme for Kame.io.
///
/// The nav bar is translucent and the screens are dark, so everything is
/// expressed as tokens here instead of hard-coded colours in widgets.
class KameTokens {
  KameTokens._();

  static const Color background = Color(0xFF06070D);
  static const Color surface = Color(0xFF0D1020);
  static const Color primary = Color(0xFF6EE7F9);
  static const Color secondary = Color(0xFF7C9CFF);
  static const Color onSurface = Color(0xFFE8ECFA);
  static const Color muted = Color(0xFF8C93B5);

  /// Glass surfaces (nav bar, sheets, cards).
  static const Color glassFill = Color(0x14FFFFFF); // white @ 8%
  static const Color glassStroke = Color(0x24FFFFFF); // white @ 14%

  /// Radius / spacing scale.
  static const double radiusPill = 999;
  static const double radiusCard = 20;
  static const double gap = 16;

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration smooth = Duration(milliseconds: 380);
  static const Curve spring = Curves.easeOutCubic;
}

class KameTheme {
  KameTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: KameTokens.primary,
      secondary: KameTokens.secondary,
      surface: KameTokens.surface,
      onSurface: KameTokens.onSurface,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: KameTokens.background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: KameTokens.onSurface,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: KameTokens.onSurface,
        displayColor: KameTokens.onSurface,
      ),
      iconTheme: const IconThemeData(color: KameTokens.muted),
      dividerTheme: const DividerThemeData(color: KameTokens.glassStroke, space: 0),
      listTileTheme: const ListTileThemeData(
        iconColor: KameTokens.muted,
        textColor: KameTokens.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KameTokens.primary
              : KameTokens.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KameTokens.primary.withOpacity(0.25)
              : const Color(0x1FFFFFFF),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(KameTokens.glassStroke),
      ),
    );
  }
}
