import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../shape/clay_squircle.dart';
import '../theme/clay_tokens.dart';
import 'clay_glyph_view.dart';
import 'clay_surface.dart';

/// Um segmento do veio (Foto / Vídeo, ou Sistema / Completo / Reduzido).
@immutable
class ClaySegment {
  const ClaySegment({
    required this.label,
    required this.glyph,
    this.semanticLabel,
  });

  final String label;
  final List<ClayStroke> glyph;
  final String? semanticLabel;
}

/// Botão de glifo com rótulo opcional.
///
/// Todo controle de ação do app usa este componente: área de toque mínima de
/// 48 px, rótulo sempre visível quando há espaço (rótulo não é decoração, é
/// o que transforma um ícone ambíguo em uma função inequívoca), foco visível
/// e estado selecionado por **volume + cor**, nunca só por cor.
class ClayIconButton extends StatelessWidget {
  const ClayIconButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.kind = ClayMaterialKind.porcelain,
    this.selected = false,
    this.tone,
    this.glyphSize = 22,
    this.width = 56,
    this.height = 62,
    this.showLabel = true,
    this.enabled = true,
    this.glow,
    this.tooltip,
    this.identity,
    this.onLongPress,
  });

  final List<ClayStroke> glyph;
  final String label;
  final VoidCallback onTap;
  final ClayMaterialKind kind;
  final bool selected;
  final Color? tone;
  final double glyphSize;
  final double width;
  final double height;
  final bool showLabel;
  final bool enabled;
  final Color? glow;
  final String? tooltip;
  final Object? identity;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final idle = kind == ClayMaterialKind.porcelain
        ? ClayPalette.inkSoft
        : ClayPalette.ash;
    final active = tone ?? ClayPalette.kiln;
    final color = !enabled
        ? idle.withOpacity(0.45)
        : selected
            ? active
            : idle;

    return ClaySurface(
      kind: kind,
      width: width,
      height: height,
      radius: ClayRadii.control,
      padding: const EdgeInsets.symmetric(horizontal: ClaySpace.xs),
      elevation: selected ? ClayElevation.l1 : ClayElevation.flat,
      tint: selected ? active : null,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: label,
      tooltip: tooltip,
      glow: selected ? (glow ?? active) : glow,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClayGlyphSwap(
            glyph: glyph,
            identity: identity ?? Object.hash(label, selected),
            size: glyphSize,
            color: color,
          ),
          if (showLabel) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ClayType.micro(color: color),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pintor do sulco: a canaleta por onde a matéria do veio escorre.
///
/// É o inverso do relevo — luz embaixo, sombra em cima — para o olho ler
/// profundidade em vez de altura.
class ClayGroovePainter extends CustomPainter {
  const ClayGroovePainter({
    this.radius = 24,
    this.depth = 0.34,
  });

  final double radius;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = ClayShape.squircle(rect, radius);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF000000).withOpacity(depth),
            const Color(0xFF000000).withOpacity(depth * 0.25),
          ],
        ).createShader(rect),
    );

    canvas
      ..save()
      ..clipPath(path);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: const Alignment(0, 0.5),
          colors: <Color>[
            const Color(0xFF000000).withOpacity(depth + 0.16),
            const Color(0xFF000000).withOpacity(0),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(0, 0.6),
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.28),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClayGroovePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.depth != depth;
}

/// O **veio**: o seletor de modo.
///
/// Em vez de um pill que aparece e desaparece, a massa **escorre** pelo sulco
/// até a posição escolhida (curva `melt`: sai devagar, acelera, freia). É a
/// peça de assinatura do CLAY MORPHIST: o modo ativo não é um estado pintado,
/// é o lugar para onde a matéria foi.
class ClayVein extends StatelessWidget {
  const ClayVein({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 60,
    this.tone = ClayPalette.kiln,
    this.semanticLabel,
  });

  final List<ClaySegment> segments;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;
  final Color tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);
    final count = segments.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        var max = constraints.maxWidth;
        if (!max.isFinite) {
          max = MediaQuery.sizeOf(context).width - (ClaySpace.gutter * 2);
        }
        final itemWidth = max / count;

        return Semantics(
          label: semanticLabel,
          child: SizedBox(
            height: height,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: ClayGroovePainter(radius: height / 2),
                  ),
                ),
                AnimatedPositioned(
                  left: 4 + selected * itemWidth,
                  top: 4,
                  bottom: 4,
                  width: itemWidth - 8,
                  duration: motion.d(ClayDurations.morph),
                  curve: motion.curve(ClayCurves.melt),
                  child: CustomPaint(
                    painter: ClaySurfacePainter(
                      kind: ClayMaterialKind.porcelain,
                      radius: (height - 8) / 2,
                      press: 0,
                      hovered: false,
                      focused: false,
                      enabled: true,
                      elevation: ClayElevation.l2,
                      tint: tone,
                      tintStrength: 0.32,
                    ),
                  ),
                ),
                Row(
                  children: List<Widget>.generate(count, (index) {
                    final segment = segments[index];
                    final isSelected = index == selected;
                    return Expanded(
                      child: ClayPressable(
                        semanticLabel: segment.semanticLabel ?? segment.label,
                        onTap: () => onChanged(index),
                        builder: (context, state) {
                          final press = state.press.clamp(-0.2, 1.0);
                          return Transform.scale(
                            scale: 1 - 0.05 * press,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ClayGlyphSwap(
                                  glyph: segment.glyph,
                                  identity:
                                      Object.hash(segment.label, isSelected),
                                  size: 21,
                                  color: isSelected
                                      ? ClayPalette.kilnDark
                                      : ClayPalette.inkSoft,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  segment.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ClayType.micro(
                                    color: isSelected
                                        ? ClayPalette.ink
                                        : ClayPalette.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Chave de forno.
///
/// O puck não desliza: ele é **empurrado** e se comprime no trajeto
/// (scaleX/scaleY cruzados), e a massa muda de cor porque foi queimada —
/// porcelain frio desligado, esmalte aceso ligado.
class ClaySwitch extends StatelessWidget {
  const ClaySwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.height = 34,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;
  final double height;

  static const double _widthFactor = 1.72;

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);
    final width = height * _widthFactor;
    final puck = height - 8;

    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: value ? 1 : 0, end: value ? 1 : 0),
        duration: motion.d(ClayDurations.quick),
        curve: motion.curve(ClayCurves.squish),
        builder: (context, t, _) {
          final travel = (width - puck - 8) * t;
          return ClayPressable(
            onTap: () {
              ClayHaptics.tap(context);
              onChanged(!value);
            },
            semanticLabel: semanticLabel,
            builder: (context, state) {
              final press = state.press.clamp(-0.2, 1.0);
              return Transform.scale(
                scale: 1 - 0.03 * press,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(
                          painter: ClayGroovePainter(
                            radius: height / 2,
                            depth: 0.42,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 4 + travel,
                        top: 4,
                        child: Transform.scale(
                          scaleX: 1 + 0.12 * press,
                          scaleY: 1 - 0.1 * press,
                          child: CustomPaint(
                            size: Size.square(puck),
                            painter: ClaySurfacePainter(
                              kind: ClayMaterialKind.porcelain,
                              radius: puck / 2,
                              press: press,
                              hovered: state.hovered,
                              focused: state.focused,
                              enabled: true,
                              elevation: ClayElevation.l1,
                              body: LinearGradient.lerp(
                                ClayPalette.porcelainBody,
                                ClayPalette.kilnBody,
                                t,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// O obturador: a peça mais quente da interface.
///
/// Três comportamentos, um só objeto:
///  * **foto** — blob de esmalte com anel interno; ao disparar, uma onda de
///    choque sai da peça (o `pulse`);
///  * **vídeo** — a massa encolhe e vira um quadrado de stop, e a brasa
///    respira (desligada em movimento reduzido);
///  * **câmera indisponível** — a peça esfria e afunda, sem brasa.
class ClayShutter extends StatefulWidget {
  const ClayShutter({
    super.key,
    required this.recording,
    required this.ready,
    required this.pulse,
    required this.onTap,
    this.diameter = 60,
  });

  final bool recording;
  final bool ready;
  final int pulse;
  final VoidCallback onTap;
  final double diameter;

  @override
  State<ClayShutter> createState() => _ClayShutterState();
}

class _ClayShutterState extends State<ClayShutter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: ClayDurations.sculpt,
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: ClayDurations.breathe,
  );
  late final Listenable _ticks = Listenable.merge(<Listenable>[_wave, _breath]);

  int _seenPulse = 0;

  @override
  void initState() {
    super.initState();
    _seenPulse = widget.pulse;
    _syncBreath();
  }

  @override
  void didUpdateWidget(covariant ClayShutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != _seenPulse) {
      _seenPulse = widget.pulse;
      _wave.forward(from: 0);
    }
    if (widget.recording != oldWidget.recording) _syncBreath();
  }

  void _syncBreath() {
    final reduced = ClayMotionScope.of(context).reduced;
    if (widget.recording && !reduced) {
      _breath.repeat(reverse: true);
    } else {
      _breath
        ..stop()
        ..value = 0.35;
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);

    return AnimatedBuilder(
      animation: _ticks,
      builder: (context, _) {
        final wave = _wave.value;
        final breath = _breath.value;
        final recording = widget.recording;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
              begin: recording ? 1.0 : 0.0, end: recording ? 1.0 : 0.0),
          duration: motion.d(ClayDurations.morph),
          curve: motion.curve(ClayCurves.squish),
          builder: (context, t, _) {
            final size =
                ui.lerpDouble(widget.diameter, widget.diameter * 0.56, t)!;

            return SizedBox(
              width: widget.diameter * 2.4,
              height: widget.diameter * 2.4,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Onda de choque da captura.
                    if (wave > 0)
                      CustomPaint(
                        size: Size.square(widget.diameter * 2.4),
                        painter: _WavePainter(
                          progress: wave,
                          radius: ui.lerpDouble(
                            widget.diameter * 0.5,
                            widget.diameter * 1.9,
                            wave,
                          )!,
                          color: ClayPalette.kiln,
                        ),
                      ),
                    // Brasa — respira enquanto grava.
                    CustomPaint(
                      size: Size.square(widget.diameter * 1.9),
                      painter: _HaloPainter(
                        radius: size * 0.5 * (0.92 + 0.14 * breath),
                        opacity: recording ? 0.18 + 0.22 * breath : 0.3,
                        color: recording ? ClayPalette.ember : ClayPalette.kiln,
                      ),
                    ),
                    ClaySurface(
                      kind: ClayMaterialKind.glaze,
                      width: size,
                      height: size,
                      radius: size / 2,
                      padding: EdgeInsets.zero,
                      elevation: ClayElevation.l3,
                      enabled: widget.ready,
                      glow: widget.ready ? ClayPalette.kiln : null,
                      semanticLabel:
                          recording ? 'Parar gravação' : 'Obturador, capturar',
                      onTap: widget.onTap,
                      child: AnimatedOpacity(
                        opacity: recording ? 0 : 1,
                        duration: motion.d(ClayDurations.quick),
                        child: Container(
                          width: size - 20,
                          height: size - 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.55),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.progress,
    required this.radius,
    required this.color,
  });

  final double progress;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = color.withOpacity(0.55 * (1 - progress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * (1 - progress) + 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      oldDelegate.progress != progress ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color;
}

class _HaloPainter extends CustomPainter {
  const _HaloPainter({
    required this.radius,
    required this.opacity,
    required this.color,
  });

  final double radius;
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) =>
      oldDelegate.radius != radius ||
      oldDelegate.opacity != opacity ||
      oldDelegate.color != color;
}

/// Etiqueta de estado (timer de gravação, contadores, selos).
class ClayChip extends StatelessWidget {
  const ClayChip({
    super.key,
    required this.label,
    this.glyph,
    this.tone = ClayPalette.ember,
    this.kind = ClayMaterialKind.obsidian,
  });

  final String label;
  final List<ClayStroke>? glyph;
  final Color tone;
  final ClayMaterialKind kind;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      kind: kind,
      pressable: false,
      radius: ClayRadii.pill,
      elevation: ClayElevation.l1,
      padding: const EdgeInsets.symmetric(
        horizontal: ClaySpace.sm + 2,
        vertical: ClaySpace.xs + 1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            ClayGlyphView(glyph: glyph!, size: 14, color: tone),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: ClayType.numeric(color: ClayPalette.chalk, size: 13),
          ),
        ],
      ),
    );
  }
}
