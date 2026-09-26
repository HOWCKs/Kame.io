import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/clay_motion.dart';
import '../theme/clay_tokens.dart';

/// Uma amostra de massa: centro e raio em pixels.
@immutable
class ClaySample {
  const ClaySample(this.center, this.radius);

  final Offset center;
  final double radius;
}

/// Campo de argila interativo — o “ClayMorphis 3D”.
///
/// Composição de metaballs resolvida **analiticamente**: para cada bloco, o
/// contorno é amostrado por 48 raios que saem do seu centro; em cada raio o
/// limite do campo (Σ rᵢ²/dᵢ² = 1) é encontrado por varredura grossa + bisseção.
/// Os polígonos resultantes são unidos com `PathOperation.union`.
///
/// Por que amostragem radial e não marching squares? Porque assim cada bloco
/// preserva seu próprio contorno mesmo quando está separado dos outros (ilhas
/// não desaparecem), o caminho já sai fechado e suave, e o custo é previsível:
/// ~14 mil avaliações de campo por quadro, sem alocação de grid.
///
/// O volume vem da luz, não da geometria: sombra de contato, gradiente na
/// direção da fonte, especular deslocado, terminador interno e rim light — a
/// fonte segue o dedo, então a peça responde como matéria iluminada.
class ClayField extends StatefulWidget {
  const ClayField({
    super.key,
    this.tone = ClayPalette.kiln,
    this.height,
    this.interactive = true,
    this.hint,
    this.drift = true,
    this.quality = 48,
    this.semanticLabel = 'Superfície de argila interativa',
  });

  final Color tone;
  final double? height;
  final bool interactive;
  final String? hint;
  final bool drift;
  final int quality;
  final String? semanticLabel;

  /// Composição padrão: cinco massas que se tocam, mas não se fundem por
  /// completo — a silhueta tem “pescoços”, e é neles que o movimento aparece.
  static const List<List<double>> composition = <List<double>>[
    <double>[0.34, 0.44, 0.30, 0.00], // x, y, raio, fase
    <double>[0.66, 0.37, 0.26, 0.18],
    <double>[0.52, 0.66, 0.28, 0.42],
    <double>[0.25, 0.68, 0.19, 0.66],
    <double>[0.76, 0.66, 0.18, 0.84],
  ];

  @override
  State<ClayField> createState() => _ClayFieldState();
}

class _ClayFieldState extends State<ClayField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );
  late final AnimationController _grab = AnimationController(
    vsync: this,
    duration: ClayDurations.quick,
    value: 0,
  );

  late final Listenable _ticks = Listenable.merge(<Listenable>[_drift, _grab]);

  Offset? _pointer;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _syncDrift();
  }

  @override
  void didUpdateWidget(covariant ClayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drift != widget.drift) _syncDrift();
  }

  void _syncDrift() {
    final reduced = ClayMotionScope.of(context).reduced;
    if (widget.drift && !reduced) {
      _drift.repeat();
    } else {
      _drift
        ..stop()
        ..value = 0.22;
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _grab.dispose();
    super.dispose();
  }

  void _start(Offset local) {
    if (!widget.interactive) return;
    setState(() {
      _pointer = local;
      _touched = true;
    });
    _grab.animateTo(1, curve: Curves.easeOut);
  }

  void _move(Offset local) {
    if (!widget.interactive) return;
    setState(() => _pointer = local);
  }

  void _end() {
    if (!widget.interactive) return;
    _grab.animateTo(0, duration: ClayDurations.morph, curve: ClayCurves.softOut);
  }

  List<ClaySample> _samples(Size size) {
    final t = _drift.value;
    final min = size.shortestSide;
    final grab = _grab.value;
    final pointer = _pointer;

    final samples = <ClaySample>[];
    for (final seed in ClayField.composition) {
      // Frequência 1: o laço fecha exatamente, sem salto perceptível.
      final phase = seed[3];
      final dx = math.sin(2 * math.pi * (t + phase)) * 0.022 * size.width;
      final dy = math.cos(2 * math.pi * (t + phase * 1.7)) * 0.026 * size.height;

      var center = Offset(seed[0] * size.width + dx, seed[1] * size.height + dy);
      final radius = seed[2] * min;

      // A matéria é puxada pelo dedo — quanto mais perto, mais estica.
      if (pointer != null && grab > 0) {
        final to = pointer - center;
        final dist = to.distance;
        final reach = radius * 3.4;
        if (dist < reach && dist > 0.001) {
          final falloff = 1 - (dist / reach);
          center = center + to / dist * (radius * 0.55 * falloff * falloff * grab);
        }
      }
      samples.add(ClaySample(center, radius));
    }

    // O próprio dedo vira massa enquanto pressiona.
    if (pointer != null && grab > 0.01) {
      samples.add(ClaySample(pointer, 0.2 * min * grab));
    }
    return samples;
  }

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = widget.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 220);
        final size = Size(width, height.toDouble());

        return Semantics(
          label: widget.semanticLabel,
          hint: widget.interactive ? 'Arraste para deformar a matéria' : null,
          child: AnimatedBuilder(
            animation: _ticks,
            builder: (context, _) {
              final samples = _samples(size);
              final light = _pointer == null
                  ? const Offset(-0.6, -0.75)
                  : Offset(
                      ((_pointer!.dx / width) * 2 - 1).clamp(-1.0, 1.0),
                      ((_pointer!.dy / height) * 2 - 1).clamp(-1.0, 1.0),
                    );

              Widget field = ExcludeSemantics(
                child: CustomPaint(
                  size: size,
                  painter: ClayFieldPainter(
                    samples: samples,
                    light: light,
                    tone: widget.tone,
                    angles: widget.quality,
                  ),
                ),
              );

              if (widget.interactive) {
                field = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) => _start(details.localPosition),
                  onPanStart: (details) => _start(details.localPosition),
                  onPanUpdate: (details) => _move(details.localPosition),
                  onPanEnd: (_) => _end(),
                  onPanCancel: _end,
                  child: field,
                );
              }

              if (widget.hint == null) return field;

              return Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  field,
                  AnimatedOpacity(
                    opacity: _touched ? 0 : 1,
                    duration: motion.d(ClayDurations.morph),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: ClaySpace.sm),
                      child: Text(
                        widget.hint!,
                        style: ClayType.micro(color: ClayPalette.smoke),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Pintor do campo de argila.
class ClayFieldPainter extends CustomPainter {
  ClayFieldPainter({
    required this.samples,
    required this.light,
    required this.tone,
    this.angles = 48,
  });

  final List<ClaySample> samples;
  final Offset light;
  final Color tone;
  final int angles;

  /// Campo de metaballs: Σ rᵢ²/dᵢ². A superfície é o nível 1.
  static double fieldAt(List<ClaySample> samples, Offset p) {
    var sum = 0.0;
    for (final s in samples) {
      final dx = p.dx - s.center.dx;
      final dy = p.dy - s.center.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < 0.0001) return 10;
      sum += (s.radius * s.radius) / d2;
    }
    return sum;
  }

  /// Contorno da massa. Público para que os testes validem a matemática real
  /// (campo + bisseção + união), não uma reimplementação dela.
  static Path surfaceFor(
    List<ClaySample> samples,
    Size size, {
    int angles = 48,
  }) {
    Path? union;
    final maxR = size.longestSide;

    for (final s in samples) {
      final points = <Offset>[];
      final step = (s.radius * 0.42).clamp(2.0, 40.0);

      for (var i = 0; i < angles; i++) {
        final angle = (i / angles) * 2 * math.pi;
        final dx = math.cos(angle);
        final dy = math.sin(angle);

        var lo = s.radius * 0.5;
        var hi = lo;
        var guard = 0;
        while (hi < maxR &&
            fieldAt(samples, Offset(s.center.dx + dx * hi, s.center.dy + dy * hi)) > 1) {
          lo = hi;
          hi += step;
          if (++guard > 72) break;
        }

        // Bisseção: 6 iterações dão precisão sub-pixel em qualquer densidade.
        for (var k = 0; k < 6; k++) {
          final mid = (lo + hi) * 0.5;
          if (fieldAt(samples, Offset(s.center.dx + dx * mid, s.center.dy + dy * mid)) >
              1) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        points.add(Offset(s.center.dx + dx * lo, s.center.dy + dy * lo));
      }

      final blob = _smoothClosedPath(points);
      union = union == null
          ? blob
          : Path.combine(PathOperation.union, union, blob);
    }

    return union ?? Path();
  }

  /// Polígono suavizado por quadráticas nos pontos médios — remove a
  /// facetagem sem introduzir oscilação (caso clássico do Catmull-Rom mal
  /// parametrizado).
  static Path _smoothClosedPath(List<Offset> points) {
    final path = Path();
    final n = points.length;
    if (n < 3) return path;

    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    final start = mid(points[n - 1], points[0]);
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final current = points[i];
      final next = points[(i + 1) % n];
      final m = mid(current, next);
      path.quadraticBezierTo(current.dx, current.dy, m.dx, m.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final path = surfaceFor(samples, size, angles: angles);
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;

    final hsl = HSLColor.fromColor(tone);
    final lightEnd = light.dx.abs() < 0.05 && light.dy.abs() < 0.05
        ? const Offset(-0.6, -0.75)
        : light;

    // 1. sombra de contato
    canvas.drawPath(
      path.shift(Offset(0, bounds.height * 0.06 + 6)),
      Paint()
        ..color = const Color(0xFF000000).withOpacity(0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // 2. corpo iluminado
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(lightEnd.dx, lightEnd.dy),
          end: Alignment(-lightEnd.dx, -lightEnd.dy),
          colors: <Color>[
            hsl.withLightness(0.66).toColor(),
            hsl.withLightness(0.48).toColor(),
            hsl.withLightness(0.28).toColor(),
          ],
          stops: const <double>[0, 0.46, 1],
        ).createShader(bounds),
    );

    canvas
      ..save()
      ..clipPath(path);

    // 3. especular deslocado para a fonte de luz
    final specRadius = bounds.shortestSide * 0.42;
    final specCenter = Offset(
      bounds.left + bounds.width * (0.5 + 0.26 * lightEnd.dx),
      bounds.top + bounds.height * (0.5 + 0.28 * lightEnd.dy),
    );
    canvas.drawCircle(
      specCenter,
      specRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withOpacity(0.42),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: specCenter, radius: specRadius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 4. terminador: a massa escurece do lado oposto à luz
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(lightEnd.dx, lightEnd.dy),
          end: Alignment(-lightEnd.dx, -lightEnd.dy),
          colors: <Color>[
            const Color(0xFF000000).withOpacity(0),
            const Color(0xFF000000).withOpacity(0.5),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bounds.shortestSide * 0.22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 5. rim light — separa a massa do fundo
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(lightEnd.dx, lightEnd.dy),
          end: Alignment(-lightEnd.dx, -lightEnd.dy),
          colors: <Color>[
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClayFieldPainter old) => true;
}
