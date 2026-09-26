import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';

/// Geometria da matéria.
///
/// Nenhuma superfície do CLAY MORPHIST usa canto circular puro: um círculo
/// encontra a reta tangencialmente e “quebra” a leitura do volume. O sistema
/// usa uma **superelipse aproximada por cúbicas** — as alças de Bézier são
/// mais longas que as do arco circular (0.62 vs 0.5523), o que preenche o
/// canto e faz a borda parecer tensionada, como argila cortada.
class ClayShape {
  ClayShape._();

  /// Fator da alça: 0.5523 = arco circular perfeito; acima disso o canto fica
  /// mais cheio (squircle). 0.62 foi calibrado para a superelipse n≈3.2.
  static const double _handle = 0.62;

  /// Retângulo de cantos contínuos (squircle).
  static Path squircle(Rect rect, double radius) {
    final r = radius.clamp(
      0.0,
      math.min(rect.width, rect.height) / 2,
    );
    final k = r * _handle;
    return Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..cubicTo(
        rect.right - r + k,
        rect.top,
        rect.right,
        rect.top + r - k,
        rect.right,
        rect.top + r,
      )
      ..lineTo(rect.right, rect.bottom - r)
      ..cubicTo(
        rect.right,
        rect.bottom - r + k,
        rect.right - r + k,
        rect.bottom,
        rect.right - r,
        rect.bottom,
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..cubicTo(
        rect.left + r - k,
        rect.bottom,
        rect.left,
        rect.bottom - r + k,
        rect.left,
        rect.bottom - r,
      )
      ..lineTo(rect.left, rect.top + r)
      ..cubicTo(
        rect.left,
        rect.top + r - k,
        rect.left + r - k,
        rect.top,
        rect.left + r,
        rect.top,
      )
      ..close();
  }

  /// Círculo achatado — usado quando a matéria é comprimida (estado premido).
  static Path squish(Rect rect, double radius, double amount) {
    final squashed = Rect.fromCenter(
      center: rect.center,
      width: rect.width * (1 + 0.06 * amount),
      height: rect.height * (1 - 0.09 * amount),
    );
    return squircle(squashed, radius);
  }

  /// Silhueta da barra de controle: squircle com uma **cúpula** no topo
  /// central. O obturador nasce dentro dessa cúpula e fica metade para fora —
  /// a massa cresce para recebê-lo em vez de ser recortada.
  static Path domeBar({
    required Rect rect,
    required double corner,
    required double domeRadius,
  }) {
    final r = corner.clamp(0.0, math.min(rect.width, rect.height) / 2);
    final dome = domeRadius.clamp(0.0, math.min(rect.width, rect.height) / 2);
    final k = r * _handle;
    final cx = rect.center.dx;
    final top = rect.top;
    final domeRect = Rect.fromCircle(
      center: Offset(cx, top),
      radius: dome,
    );

    return Path()
      ..moveTo(rect.left + r, top)
      ..lineTo(cx - dome, top)
      // Semicírculo para cima: a cúpula soma matéria, não a remove.
      ..arcTo(domeRect, math.pi, math.pi, false)
      ..lineTo(rect.right - r, top)
      ..cubicTo(
        rect.right - r + k,
        top,
        rect.right,
        top + r - k,
        rect.right,
        top + r,
      )
      ..lineTo(rect.right, rect.bottom - r)
      ..cubicTo(
        rect.right,
        rect.bottom - r + k,
        rect.right - r + k,
        rect.bottom,
        rect.right - r,
        rect.bottom,
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..cubicTo(
        rect.left + r - k,
        rect.bottom,
        rect.left,
        rect.bottom - r + k,
        rect.left,
        rect.bottom - r,
      )
      ..lineTo(rect.left, top + r)
      ..cubicTo(
        rect.left,
        top + r - k,
        rect.left + r - k,
        top,
        rect.left + r,
        top,
      )
      ..close();
  }
}

/// `ShapeBorder` do squircle — usado em `Material`, `InkWell` e recortes.
class ClaySquircle extends ShapeBorder {
  const ClaySquircle({this.radius = ClayRadii.card, this.n = 3.2});

  final double radius;
  final double n;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      ClayShape.squircle(rect, radius);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      ClayShape.squircle(rect, radius);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => ClaySquircle(radius: radius * t, n: n);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ClaySquircle) {
      return ClaySquircle(
        radius: ui.lerpDouble(a.radius, radius, t) ?? radius,
        n: ui.lerpDouble(a.n, n, t) ?? n,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ClaySquircle) {
      return ClaySquircle(
        radius: ui.lerpDouble(radius, b.radius, t) ?? radius,
        n: ui.lerpDouble(n, b.n, t) ?? n,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is ClaySquircle && other.radius == radius && other.n == n;

  @override
  int get hashCode => Object.hash(radius, n);
}
