import 'package:flutter/material.dart';

import '../shape/clay_squircle.dart';
import 'clay_tokens.dart';

/// Tema Material do Kame.io.
///
/// O Material aqui é só a **infraestrutura** (foco, semântica, navegação,
/// leitor de tela). Toda a superfície visível é desenhada pelos componentes
/// de argila; o que sobra para o `ThemeData` é garantir que diálogos, sheets,
/// snackbars e indicadores — as peças que o sistema Android e o leitor de
/// tela esperam — falem a mesma língua de cor, forma e contraste.
class ClayTheme {
  ClayTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: ClayPalette.kiln,
      onPrimary: Color(0xFFFFFFFF),
      secondary: ClayPalette.cobalt,
      onSecondary: Color(0xFFFFFFFF),
      error: ClayPalette.ember,
      onError: Color(0xFFFFFFFF),
      surface: ClayPalette.clayMid,
      onSurface: ClayPalette.chalk,
      outline: ClayPalette.rim,
      outlineVariant: ClayPalette.rimStrong,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ClayPalette.abyss,
      canvasColor: ClayPalette.bedrock,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: ClayType.textTheme(brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ClayPalette.chalk,
      ),
      iconTheme: const IconThemeData(color: ClayPalette.ash, size: 22),
      dividerTheme: const DividerThemeData(color: ClayPalette.rim, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: ClayPalette.ash,
        textColor: ClayPalette.chalk,
        minVerticalPadding: ClaySpace.sm,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ClayPalette.kiln,
        linearTrackColor: ClayPalette.clayMid,
        circularTrackColor: ClayPalette.clayMid,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ClayPalette.clayMid,
        contentTextStyle: ClayType.bodySm(color: ClayPalette.chalk),
        behavior: SnackBarBehavior.floating,
        shape: const ClaySquircle(radius: ClayRadii.chip),
        elevation: 0,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: ClayType.section(),
        contentTextStyle: ClayType.bodySm(color: ClayPalette.ash),
        shape: const ClaySquircle(radius: ClayRadii.sheet),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ClayPalette.clayHigh,
          borderRadius: BorderRadius.circular(ClayRadii.chip),
          border: Border.all(color: ClayPalette.rimStrong),
        ),
        textStyle: ClayType.micro(color: ClayPalette.chalk),
        padding: const EdgeInsets.symmetric(
          horizontal: ClaySpace.sm + 2,
          vertical: ClaySpace.xs + 2,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClayPalette.chalk,
          textStyle: ClayType.label(),
          minimumSize: const Size(64, 48),
          shape: const ClaySquircle(radius: ClayRadii.chip),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClayPalette.kiln,
          foregroundColor: Colors.white,
          textStyle: ClayType.label(color: Colors.white),
          minimumSize: const Size(64, 48),
          shape: const ClaySquircle(radius: ClayRadii.chip),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? ClayPalette.kiln
              : ClayPalette.porcelain,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? ClayPalette.kiln.withOpacity(0.3)
              : const Color(0x1FFFFFFF),
        ),
        trackOutlineColor:
            const WidgetStatePropertyAll<Color>(ClayPalette.rimStrong),
      ),
    );
  }
}
