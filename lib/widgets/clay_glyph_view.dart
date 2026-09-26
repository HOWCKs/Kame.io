import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../theme/clay_tokens.dart';

/// Desenha um glifo do CLAY MORPHIST.
///
/// O glifo é pintado com `PathMetrics`: cada contorno recebe uma fatia do
/// tempo de 0→1, então o ícone **se desenha** em vez de aparecer. É o mesmo
/// princípio da matéria se reorganizando — o traço é depositado, não surgido.
class ClayGlyphView extends StatelessWidget {
  const ClayGlyphView({
    super.key,
    required this.glyph,
    this.size = 22,
    this.color = ClayPalette.chalk,
    this.progress = 1,
    this.weight = 1,
  });

  final List<ClayStroke> glyph;
  final double size;
  final Color color;

  /// 0 = nada desenhado, 1 = glifo completo.
  final double progress;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(
        glyph: glyph,
        color: color,
        progress: progress.clamp(0.0, 1.0),
        weight: weight,
      ),
    );
  }
}

class _Run {
  _Run(this.metric, this.stroke);

  final PathMetric metric;
  final ClayStroke stroke;
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.progress,
    required this.weight,
  });

  final List<ClayStroke> glyph;
  final Color color;
  final double progress;
  final double weight;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || glyph.isEmpty || size.isEmpty) return;

    final runs = <_Run>[];
    var total = 0.0;
    for (final stroke in glyph) {
      for (final metric in stroke.path.computeMetrics()) {
        if (metric.length <= 0) continue;
        runs.add(_Run(metric, stroke));
        total += metric.length;
      }
    }
    if (runs.isEmpty || total <= 0) return;

    final scale = size.width / 24;
    canvas
      ..save()
      ..scale(scale, scale);

    final drawn = total * progress;
    var consumed = 0.0;
    for (final run in runs) {
      final visible =
          (drawn - consumed).clamp(0.0, run.metric.length).toDouble();
      consumed += run.metric.length;
      if (visible <= 0) break;

      final paint = Paint()
        ..color = color.withOpacity(run.stroke.opacity.clamp(0.0, 1.0))
        ..style = run.stroke.filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = run.stroke.width * weight
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(run.metric.extractPath(0, visible), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.weight != weight ||
      oldDelegate.glyph != glyph;
}

/// Troca de glifo com **reforma da matéria**: o ícone novo se desenha a partir
/// do zero enquanto cresce de 88% até 100%, e o anterior desaparece.
///
/// Não é interpolação ponto a ponto (isso exigiria topologia idêntica entre
/// os dois caminhos e quebraria a qualquer mudança de desenho). É uma decisão
/// consciente: o custo de manter paridade topológica é alto e o ganho, em
/// ícones de 22 px, é imperceptível.
class ClayGlyphSwap extends StatelessWidget {
  const ClayGlyphSwap({
    super.key,
    required this.glyph,
    this.identity,
    this.size = 22,
    this.color = ClayPalette.chalk,
    this.weight = 1,
    this.animate = true,
  });

  final List<ClayStroke> glyph;

  /// Muda para reiniciar o desenho (use o estado que define o glifo).
  final Object? identity;
  final double size;
  final Color color;
  final double weight;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);
    if (!animate || motion.reduced) {
      return ClayGlyphView(
        glyph: glyph,
        size: size,
        color: color,
        weight: weight,
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<Object?>(identity ?? glyph),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: motion.d(ClayDurations.morph),
      curve: motion.curve(ClayCurves.softOut),
      builder: (context, t, _) {
        return Transform.scale(
          scale: 0.88 + 0.12 * t,
          child: ClayGlyphView(
            glyph: glyph,
            size: size,
            color: color,
            progress: t,
            weight: weight,
          ),
        );
      },
    );
  }
}
