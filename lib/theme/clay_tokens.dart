import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CLAY MORPHIST — design tokens do Kame.io
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Regra nº 1 do sistema: **estado é volume, não cor**.
/// Um botão pressionado afunda, um modo ativo infla, uma transição derrete.
/// A cor entra como *esmalte mineral* por cima da matéria, nunca como
/// substituta da forma.
///
/// Existem apenas dois materiais:
///  * **obsidian** — a massa escura do corpo do app (viewfinder, fundos);
///  * **porcelain** — a argila clara dos controles (barra, sheets, cards).
///
/// A tensão entre os dois é o que dá peso à interface: luz sobre sombra,
/// matéria clara boiando sobre o vazio.
class ClayPalette {
  ClayPalette._();

  // ── Obsidian (corpo escuro) ────────────────────────────────────────────────
  static const Color abyss = Color(0xFF08090D); // scaffold
  static const Color bedrock = Color(0xFF101219); // agrupamentos
  static const Color clayLow = Color(0xFF171A23); // card raso
  static const Color clayMid = Color(0xFF1E222E); // card elevado
  static const Color clayHigh = Color(0xFF272C3A); // card pressionado / hover

  // ── Rims (bordas de luz) ──────────────────────────────────────────────────
  static const Color rim = Color(0x14FFFFFF); // branco 8%
  static const Color rimStrong = Color(0x24FFFFFF); // branco 14%
  static const Color rimDeep = Color(0x0AFFFFFF); // branco 4%

  // ── Texto sobre obsidian ──────────────────────────────────────────────────
  static const Color chalk = Color(0xFFF4F1EC); // 16.6:1 sobre abyss
  static const Color ash = Color(0xFFA7A29B); // 7.4:1
  static const Color smoke = Color(0xFF8A867F); // 5.2:1 — mínimo AA para texto

  // ── Porcelain (argila clara dos controles) ────────────────────────────────
  static const Color porcelain = Color(0xFFF2EDE6);
  static const Color porcelainEdge = Color(0xFFFFFDFA);
  static const Color porcelainShade = Color(0xFFDCD3C8);
  static const Color porcelainDeep = Color(0xFFC6BBAD);

  // ── Tinta sobre porcelain ─────────────────────────────────────────────────
  static const Color ink = Color(0xFF2A2521); // 12.1:1 sobre porcelain
  static const Color inkSoft = Color(0xFF6B625A); // 5.3:1

  // ── Esmaltes minerais (acentos) ───────────────────────────────────────────
  static const Color kiln = Color(0xFFE9642F); // terracota queimada — primária
  static const Color kilnLight = Color(0xFFFF8A4C);
  static const Color kilnDark = Color(0xFFB8431A);
  static const Color ember = Color(0xFFFF4D6D); // gravar / destrutivo
  static const Color celadon = Color(0xFF4FD1B0); // sucesso / foco
  static const Color cobalt = Color(0xFF6B8AFD); // informação / seleção
  static const Color ochre = Color(0xFFE9B44C); // flash ativo

  /// Gradiente da massa de porcelana: luz entra pelo alto à esquerda.
  static const LinearGradient porcelainBody = LinearGradient(
    begin: Alignment(-0.85, -0.9),
    end: Alignment(0.7, 0.95),
    colors: <Color>[porcelainEdge, porcelain, porcelainShade],
    stops: <double>[0, 0.48, 1],
  );

  /// Gradiente da massa escura.
  static const LinearGradient obsidianBody = LinearGradient(
    begin: Alignment(-0.8, -0.9),
    end: Alignment(0.6, 0.95),
    colors: <Color>[clayHigh, clayMid, clayLow],
    stops: <double>[0, 0.5, 1],
  );

  /// Calor do forno: usado no obturador e no modo ativo.
  static const LinearGradient kilnBody = LinearGradient(
    begin: Alignment(-0.7, -0.9),
    end: Alignment(0.6, 0.95),
    colors: <Color>[kilnLight, kiln, kilnDark],
    stops: <double>[0, 0.45, 1],
  );
}

/// Espaçamento — base de 4. Nada de valores soltos na interface.
class ClaySpace {
  ClaySpace._();

  static const double nano = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Margem lateral das superfícies flutuantes.
  static const double gutter = 16;
}

/// Raios. Toda superfície de argila é “squircle” (superelipse), não círculo:
/// é o que faz a borda parecer tensionada como matéria, igual ao hardware.
class ClayRadii {
  ClayRadii._();

  static const double chip = 12;
  static const double control = 18;
  static const double card = 24;
  static const double sheet = 32;
  static const double slab = 40;
  static const double pill = 999;

  /// Expoente da superelipse. 2 = elipse, ∞ = retângulo.
  /// 3.2 é o ponto em que a borda ainda é orgânica mas o layout continua
  /// legível — o mesmo equilíbrio usado em ícones de sistema.
  static const double squircle = 3.2;
}

/// Escala tipográfica.
///
/// A família é a padrão da plataforma (Roboto no Android, SF no iOS) — o
/// sistema foi desenhado para receber uma display font licenciada trocando
/// apenas [ClayType.family] + o asset em `pubspec.yaml`, sem tocar em layout.
class ClayType {
  ClayType._();

  static const String family = 'sans-serif';

  static TextStyle _style({
    required double size,
    required double height,
    required double tracking,
    required FontWeight weight,
    Color color = ClayPalette.chalk,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height / size,
      letterSpacing: tracking,
      fontWeight: weight,
      color: color,
      decoration: TextDecoration.none,
    );
  }

  /// 34/40 — uma ideia por tela.
  static TextStyle display({Color color = ClayPalette.chalk}) => _style(
      size: 34,
      height: 40,
      tracking: -0.7,
      weight: FontWeight.w700,
      color: color);

  /// 24/30 — títulos de tela.
  static TextStyle title({Color color = ClayPalette.chalk}) => _style(
      size: 24,
      height: 30,
      tracking: -0.4,
      weight: FontWeight.w600,
      color: color);

  /// 18/24 — títulos de seção.
  static TextStyle section({Color color = ClayPalette.chalk}) => _style(
      size: 18,
      height: 24,
      tracking: -0.2,
      weight: FontWeight.w600,
      color: color);

  /// 15/22 — leitura.
  static TextStyle body({Color color = ClayPalette.chalk}) => _style(
      size: 15, height: 22, tracking: 0, weight: FontWeight.w400, color: color);

  /// 14/20 — corpo denso e rótulos de lista.
  static TextStyle bodySm({Color color = ClayPalette.chalk}) => _style(
      size: 14, height: 20, tracking: 0, weight: FontWeight.w400, color: color);

  /// 13/16 — rótulos de ação.
  static TextStyle label({Color color = ClayPalette.chalk}) => _style(
      size: 13,
      height: 16,
      tracking: 0.1,
      weight: FontWeight.w600,
      color: color);

  /// 11/14 — etiquetas, sempre em caixa alta pelo chamador.
  /// Em controles apertados (barra), use `size: 10`.
  static TextStyle micro({Color color = ClayPalette.smoke, double size = 11}) =>
      _style(
        size: size,
        height: size + 3,
        tracking: 0.8,
        weight: FontWeight.w600,
        color: color,
      );

  /// Numéricos (timer, contadores) — largura fixa para não “dançar”.
  static TextStyle numeric(
          {Color color = ClayPalette.chalk, double size = 13}) =>
      _style(
              size: size,
              height: size + 3,
              tracking: 0,
              weight: FontWeight.w600,
              color: color)
          .copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  static TextTheme textTheme({Brightness brightness = Brightness.dark}) {
    final text =
        brightness == Brightness.dark ? ClayPalette.chalk : ClayPalette.ink;
    final soft =
        brightness == Brightness.dark ? ClayPalette.ash : ClayPalette.inkSoft;
    return TextTheme(
      displayLarge: display(color: text),
      displayMedium: title(color: text),
      displaySmall: section(color: text),
      headlineMedium: section(color: text),
      titleLarge: title(color: text),
      titleMedium: section(color: text),
      titleSmall: label(color: text),
      bodyLarge: body(color: text),
      bodyMedium: bodySm(color: text),
      bodySmall: micro(color: soft),
      labelLarge: label(color: text),
      labelMedium: label(color: soft),
      labelSmall: micro(color: soft),
    );
  }
}

/// Elevação de argila: não é só sombra projetada, é **luz interna**.
/// Cada nível combina (a) sombra externa difusa, (b) realce interno no topo,
/// (c) sombra interna embaixo — a massa parece iluminada de cima.
class ClayElevation {
  const ClayElevation({
    required this.spread,
    required this.offsetY,
    required this.opacity,
    required this.lift,
  });

  /// Nível 0 — raso: só o rim de luz.
  static const ClayElevation flat =
      ClayElevation(spread: 0, offsetY: 0, opacity: 0, lift: 0);

  /// Nível 1 — apoiado.
  static const ClayElevation l1 =
      ClayElevation(spread: 18, offsetY: 6, opacity: 0.34, lift: 0.06);

  /// Nível 2 — flutuante (barra, sheets).
  static const ClayElevation l2 =
      ClayElevation(spread: 34, offsetY: 14, opacity: 0.42, lift: 0.1);

  /// Nível 3 — suspenso (obturador, diálogos).
  static const ClayElevation l3 =
      ClayElevation(spread: 60, offsetY: 26, opacity: 0.52, lift: 0.16);

  final double spread;
  final double offsetY;
  final double opacity;

  /// Intensidade do realce interno (0–1) proporcional à altura da massa.
  final double lift;

  ClayElevation lerpTo(ClayElevation other, double t) => ClayElevation(
        spread: lerpDouble(spread, other.spread, t) ?? spread,
        offsetY: lerpDouble(offsetY, other.offsetY, t) ?? offsetY,
        opacity: lerpDouble(opacity, other.opacity, t) ?? opacity,
        lift: lerpDouble(lift, other.lift, t) ?? lift,
      );
}
