import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';

/// Núcleo CLAY MORPHIST do app: uma forma de argila que morfa sem parar e
/// cede ao toque — o dedo puxa a matéria, o toque rápido amassa e ela volta
/// com overshoot.
///
/// A volumetria é extrusão de verdade: o mesmo contorno é desenhado N vezes,
/// deslocado para baixo e escurecido, com a face iluminada por último.
class ClayMorph extends StatefulWidget {
  const ClayMorph({
    super.key,
    this.size = 160,
    this.color = ClayTokens.clay,
    this.layers = 12,
    this.points = 42,
    this.interactive = true,
    this.label = 'Forma de argila interativa',
  });

  final double size;
  final Color color;
  final int layers;
  final int points;
  final bool interactive;
  final String label;

  @override
  State<ClayMorph> createState() => _ClayMorphState();
}

class _ClayMorphState extends State<ClayMorph> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final AnimationController _hit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  double _spin = 0;
  Offset _pull = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (!MediaQuery.of(context).disableAnimations) _idle.repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    _hit.dispose();
    super.dispose();
  }

  void _onPan(Offset local) {
    if (!widget.interactive) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = (local - center) / (widget.size / 2);
    setState(() {
      _pull = Offset(
        delta.dx.clamp(-1, 1).toDouble(),
        delta.dy.clamp(-1, 1).toDouble(),
      );
      _spin += delta.dx * 0.04;
    });
  }

  void _release() {
    if (!widget.interactive) return;
    setState(() => _pull = Offset.zero);
  }

  void _squish() {
    if (!widget.interactive) return;
    _hit.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => _onPan(details.localPosition),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          onTapDown: (_) => _squish(),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_idle, _hit]),
            builder: (context, child) {
              return CustomPaint(
                painter: _MorphPainter(
                  phase: _idle.value,
                  impulse: 1 - Curves.easeOut.transform(_hit.value),
                  color: widget.color,
                  pull: _pull,
                  spin: _spin,
                  layers: widget.layers,
                  points: widget.points,
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.phase,
    required this.impulse,
    required this.color,
    required this.pull,
    required this.spin,
    required this.layers,
    required this.points,
  });

  final double phase;
  final double impulse;
  final Color color;
  final Offset pull;
  final double spin;
  final int layers;
  final int points;

  double _radius(double th) {
    final t = phase * math.pi * 2;
    // duas formas em harmônicos, alternadas por uma senoide lenta
    final a = 1 + 0.10 * math.cos(2 * th + t) + 0.07 * math.cos(3 * th + 1.1 + t * 0.6);
    final b = 1 + 0.13 * math.cos(3 * th + 0.6) + 0.05 * math.cos(5 * th + 2.2);
    final k = (math.sin(t * 0.7) + 1) / 2;
    var r = a + (b - a) * k;
    // o dedo puxa a matéria na sua direção
    final grip = pull.distance.clamp(0, 1).toDouble();
    final d = math.max(0.0, math.cos(th - math.atan2(pull.dy, pull.dx)));
    r += grip * 0.17 * d * d;
    return r;
  }

  Path _path(Size size, double dy) {
    final c = Offset(size.width / 2, size.height / 2 + dy);
    final base = math.min(size.width, size.height).toDouble() / 2 - 26;
    final pts = <Offset>[];
    for (var i = 0; i < points; i++) {
      final th = (i / points) * math.pi * 2;
      final r = _radius(th) * base;
      pts.add(Offset(
        math.cos(th + spin) * r * (1 + impulse * 0.05),
        math.sin(th + spin) * r * (1 - impulse * 0.10),
      ));
    }
    return _smooth(c, pts);
  }

  /// Catmull-Rom fechado convertido em cúbicas de Bézier.
  Path _smooth(Offset center, List<Offset> pts) {
    final n = pts.length;
    final path = Path()..moveTo(center.dx + pts[0].dx, center.dy + pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(
        center.dx + c1.dx,
        center.dy + c1.dy,
        center.dx + c2.dx,
        center.dy + c2.dy,
        center.dx + p2.dx,
        center.dy + p2.dy,
      );
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // extrusão: do fundo (escuro, deslocado) para a frente (claro)
    for (var i = layers - 1; i >= 0; i--) {
      final p = layers <= 1 ? 1.0 : i / (layers - 1);
      final dy = (layers - 1 - i) * 2.2;
      canvas.drawPath(
        _path(size, dy),
        Paint()
          ..isAntiAlias = true
          ..color = Color.lerp(ClayTokens.darken(color, 0.62), color, p)!,
      );
    }

    final c = Offset(size.width / 2, size.height / 2);
    final face = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        Offset(c.dx - size.width * 0.15, c.dy - size.height * 0.19),
        size.width * 0.62,
        <Color>[
          ClayTokens.lighten(color, 0.46),
          color,
          ClayTokens.darken(color, 0.42),
        ],
        <double>[0, 0.55, 1],
      );
    canvas.drawPath(_path(size, 0), face);

    // brilho especular difuso
    final gloss = Paint()
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 9)
      ..shader = ui.Gradient.radial(
        Offset(c.dx - size.width * 0.16, c.dy - size.height * 0.22),
        size.width * 0.24,
        <Color>[const Color(0x8CFFF6EA), const Color(0x00FFF6EA)],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - size.width * 0.13, c.dy - size.height * 0.17),
        width: size.width * 0.44,
        height: size.height * 0.27,
      ),
      gloss,
    );
  }

  @override
  bool shouldRepaint(covariant _MorphPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.impulse != impulse ||
      oldDelegate.pull != pull ||
      oldDelegate.spin != spin ||
      oldDelegate.color != color;
}
