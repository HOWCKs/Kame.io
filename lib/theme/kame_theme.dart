import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// CLAY MORPHIST · sistema visual do Kame.io
/// ───────────────────────────────────────────────────────────────────────
/// A ideia: a interface é feita de matéria moldável. Cada superfície tem
/// volume (extrusão), luz de cima, sombra colorida embaixo e um vidro
/// translúcido por cima quando a informação precisa flutuar.
///
/// Regras do sistema:
///   · cor vem de [ClayTokens] — nenhum widget chumba hexadecimal;
///   · profundidade vem de extrusão + sombra, nunca de borda grossa;
///   · movimento tem peso: [ClayTokens.spring] com overshoot curto.
/// ═══════════════════════════════════════════════════════════════════════
class ClayTokens {
  ClayTokens._();

  // ── superfície (noite morna, não preto frio) ──────────────────────────
  static const Color night = Color(0xFF100C14);
  static const Color nightSoft = Color(0xFF191320);
  static const Color nightDeep = Color(0xFF0A0810);
  static const Color nightRim = Color(0xFF2A2136);

  // ── matéria ───────────────────────────────────────────────────────────
  static const Color clay = Color(0xFFFF8355);
  static const Color clayDeep = Color(0xFF8E2B12);
  static const Color sun = Color(0xFFFFCE63);
  static const Color violet = Color(0xFF9A87FF);
  static const Color mint = Color(0xFF35DDB0);
  static const Color sky = Color(0xFF6FCCFA);
  static const Color berry = Color(0xFFFF87B6);

  // ── tinta ─────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFFF6EFE9);
  static const Color inkSoft = Color(0xFFD8CCC2);
  static const Color muted = Color(0xFFA4939F);

  // ── estado ────────────────────────────────────────────────────────────
  static const Color ok = Color(0xFF35DDB0);
  static const Color warn = Color(0xFFF0A63C);
  static const Color danger = Color(0xFFD9453C);

  // ── vidro ─────────────────────────────────────────────────────────────
  static const Color glass = Color(0x14FFFFFF); // branco @ 8%
  static const Color glassStrong = Color(0x24FFFFFF); // branco @ 14%
  static const Color glassRim = Color(0x2EFFFFFF);
  static const double glassBlur = 18;

  // ── forma ─────────────────────────────────────────────────────────────
  static const double rXs = 10;
  static const double rSm = 14;
  static const double r = 22;
  static const double rLg = 30;
  static const double rXl = 40;
  static const double rPill = 999;
  static const double depth = 6; // espessura padrão da extrusão
  static const double gap = 16;

  // ── luz ───────────────────────────────────────────────────────────────
  static const List<BoxShadow> lift = <BoxShadow>[
    BoxShadow(color: Color(0x99000000), blurRadius: 34, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> liftSm = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> glowClay = <BoxShadow>[
    BoxShadow(color: Color(0x66FF7A45), blurRadius: 30, offset: Offset(0, 10)),
  ];

  // ── movimento ─────────────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration smooth = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 520);
  static const Curve out = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  // ── cor derivada (a matéria clareia em cima, escurece embaixo) ────────
  static Color lighten(Color c, [double amount = 0.18]) =>
      Color.lerp(c, const Color(0xFFFFF6EA), amount)!;

  static Color darken(Color c, [double amount = 0.22]) =>
      Color.lerp(c, const Color(0xFF120A06), amount)!;
}

/// Tokens herdados do Kame.io — mantidos por compatibilidade e usados pelo
/// [KameTheme] e pelos testes.
class KameTokens {
  KameTokens._();

  static const Color background = ClayTokens.night;
  static const Color surface = ClayTokens.nightSoft;
  static const Color primary = ClayTokens.clay;
  static const Color secondary = ClayTokens.violet;
  static const Color onSurface = ClayTokens.ink;
  static const Color muted = ClayTokens.muted;

  /// Vidro (barra, sheets, cards flutuantes).
  static const Color glassFill = ClayTokens.glass;
  static const Color glassStroke = ClayTokens.glassRim;

  static const double radiusPill = ClayTokens.rPill;
  static const double radiusCard = ClayTokens.r;
  static const double gap = ClayTokens.gap;

  static const Duration fast = ClayTokens.fast;
  static const Duration smooth = ClayTokens.smooth;
  static const Curve spring = ClayTokens.out;
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ClayTokens.nightSoft,
        contentTextStyle: const TextStyle(color: ClayTokens.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayTokens.r),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KameTokens.primary
              : KameTokens.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KameTokens.primary.withOpacity(0.28)
              : const Color(0x1FFFFFFF),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(KameTokens.glassStroke),
      ),
    );
  }
}
