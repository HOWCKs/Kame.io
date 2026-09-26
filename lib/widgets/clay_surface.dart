import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/clay_motion.dart';
import '../shape/clay_squircle.dart';
import '../theme/clay_tokens.dart';

/// Os dois materiais do sistema.
enum ClayMaterialKind {
  /// Massa escura do corpo do app.
  obsidian,

  /// Argila clara dos controles.
  porcelain,

  /// Esmalte queimado — só o obturador usa. É o ponto mais quente da tela.
  glaze,
}

/// Pele de um material: tudo o que muda entre obsidian, porcelain e glaze.
class _Skin {
  const _Skin({
    required this.body,
    required this.rim,
    required this.sheen,
    required this.topLight,
    required this.bottomShade,
  });

  final Gradient body;
  final Color rim;
  final double sheen;
  final double topLight;
  final double bottomShade;

  static const _Skin obsidian = _Skin(
    body: ClayPalette.obsidianBody,
    rim: ClayPalette.rim,
    sheen: 0.16,
    topLight: 1,
    bottomShade: 0.4,
  );

  static const _Skin porcelain = _Skin(
    body: ClayPalette.porcelainBody,
    rim: ClayPalette.porcelainDeep,
    sheen: 0.5,
    topLight: 1,
    bottomShade: 0.16,
  );

  static const _Skin glaze = _Skin(
    body: ClayPalette.kilnBody,
    rim: ClayPalette.kilnDark,
    sheen: 0.44,
    topLight: 1.25,
    bottomShade: 0.34,
  );
}

/// Estado de interação entregue ao builder de [ClayPressable].
@immutable
class ClayPressState {
  const ClayPressState({
    required this.press,
    required this.hovered,
    required this.focused,
    required this.enabled,
  });

  /// 0 = em repouso, 1 = totalmente premido. Pode passar de 1 no pico do
  /// toque e ficar levemente negativo na volta — é o “peso” da argila.
  final double press;
  final bool hovered;
  final bool focused;
  final bool enabled;

  static const ClayPressState idle = ClayPressState(
    press: 0,
    hovered: false,
    focused: false,
    enabled: true,
  );
}

/// Comportamento de pressão compartilhado por **todos** os controles de argila:
/// afunda em 90 ms, volta com sobrecurso elástico, mostra foco visível para
/// teclado, reage a hover no desktop e desliga tudo quando desabilitado.
///
/// Existe um só porque consistência de componente é requisito de acessibilidade,
/// não de estética: se o toque se comporta igual em todo lugar, o usuário
/// aprende o sistema uma vez.
class ClayPressable extends StatefulWidget {
  const ClayPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.enableHover = true,
  });

  final ClayPressBuilder builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;
  final bool enableHover;

  @override
  State<ClayPressable> createState() => _ClayPressableState();
}

typedef ClayPressBuilder = Widget Function(
  BuildContext context,
  ClayPressState state,
);

class _ClayPressableState extends State<ClayPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    value: 0,
    duration: ClayDurations.flick,
    vsync: this,
  );

  bool _releasing = false;
  bool _hovered = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled) return;
    _releasing = false;
    _controller
      ..duration = ClayDurations.flick
      ..animateTo(1, curve: Curves.linear);
  }

  void _up() {
    if (!widget.enabled) return;
    _releasing = true;
    final motion = ClayMotionScope.of(context);
    _controller
      ..duration = motion.d(ClayDurations.morph)
      ..animateTo(0, curve: Curves.linear);
  }

  /// O sobrecurso elástico é calculado aqui — e não na curva do controller —
  /// porque o `AnimationController` limita o valor a 0..1 e perderíamos
  /// justamente o extravasamento que dá massa ao retorno.
  double get _press {
    final v = _controller.value;
    return _releasing
        ? 1 - ClayCurves.squish.transform(1 - v)
        : ClayCurves.softOut.transform(v);
  }

  void _activate() {
    if (!widget.enabled) return;
    ClayHaptics.tap(context);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return widget.builder(
          context,
          ClayPressState(
            press: _press,
            hovered: _hovered,
            focused: _focused,
            enabled: widget.enabled,
          ),
        );
      },
    );

    child = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.enabled,
      onFocusChange: (focused) {
        if (_focused != focused) setState(() => _focused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _down();
            return KeyEventResult.handled;
          }
        } else if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _up();
            _activate();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );

    if (widget.enableHover) {
      child = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: child,
      );
    }

    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) {
        _up();
        _activate();
      },
      onTapCancel: _up,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (!widget.enabled) return;
              ClayHaptics.shape(context);
              widget.onLongPress?.call();
            },
      child: child,
    );

    if (widget.semanticLabel != null) {
      child = Semantics(
        label: widget.semanticLabel,
        button: widget.onTap != null,
        enabled: widget.enabled,
        child: child,
      );
    }

    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }

    return child;
  }
}

/// Pintor da massa.
///
/// Ordem de pintura (cada camada tem uma função, nenhuma é decorativa):
///  1. sombra projetada — informa altura;
///  2. brasa colorida — informa estado quente (obturador, modo ativo);
///  3. corpo com gradiente — informa de onde vem a luz;
///  4. realce interno no topo + sombra interna embaixo — informa volume;
///  5. brilho especular — informa que a superfície é levemente úmida (argila);
///  6. rim — separa a massa do fundo em qualquer nível de contraste;
///  7. anel de foco — só aparece para navegação por teclado.
class ClaySurfacePainter extends CustomPainter {
  const ClaySurfacePainter({
    required this.kind,
    required this.radius,
    required this.press,
    required this.hovered,
    required this.focused,
    required this.enabled,
    this.elevation = ClayElevation.l1,
    this.tint,
    this.tintStrength = 0,
    this.glow,
    this.strokeWidth = 1,
    this.specular = true,
    this.body,
  });

  final ClayMaterialKind kind;
  final double radius;
  final double press;
  final bool hovered;
  final bool focused;
  final bool enabled;
  final ClayElevation elevation;
  final Color? tint;
  final double tintStrength;
  final Color? glow;
  final double strokeWidth;
  final bool specular;

  /// Substitui o gradiente do material (usado em transições de estado, quando
  /// a massa muda de cor sem trocar de material).
  final Gradient? body;

  bool get _light => kind == ClayMaterialKind.porcelain;

  _Skin get _skin {
    switch (kind) {
      case ClayMaterialKind.obsidian:
        return _Skin.obsidian;
      case ClayMaterialKind.porcelain:
        return _Skin.porcelain;
      case ClayMaterialKind.glaze:
        return _Skin.glaze;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // A massa premida se comprime: perde altura e ganha largura.
    final path = ClayShape.squish(rect, radius, press.clamp(-1.0, 1.0));
    final lifted = hovered ? 2.0 : 0.0;
    final height = elevation.lerpTo(ClayElevation.flat, press.clamp(0.0, 1.0));

    // 1. sombra
    if (height.opacity > 0) {
      canvas.drawPath(
        path.shift(Offset(0, height.offsetY - lifted)),
        Paint()
          ..color = const Color(0xFF000000)
              .withOpacity(height.opacity * (enabled ? 1 : 0.5))
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (height.spread / 2.4).clamp(1.0, 40.0),
          ),
      );
    }

    // 2. brasa
    final emberColor = glow;
    if (emberColor != null && enabled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = emberColor.withOpacity(0.42 - 0.18 * press.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    // 3. corpo
    final paint = Paint()..shader = (body ?? _skin.body).createShader(rect);
    if (!enabled) {
      paint.colorFilter = const ColorFilter.mode(
        Color(0x8A08090D),
        BlendMode.saturation,
      );
    }
    canvas.drawPath(path, paint);

    // tinta de estado por cima do corpo
    if (tint != null && tintStrength > 0) {
      canvas.drawPath(
        path,
        Paint()..color = tint!.withOpacity(0.14 * tintStrength.clamp(0.0, 1.0)),
      );
    }

    // 4 + 5 + 6: tudo preso dentro da massa
    canvas.save();
    canvas.clipPath(path);

    final topLight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: const Alignment(0, 0.42),
        colors: <Color>[
          Colors.white.withOpacity(
            (0.62 * _skin.topLight + 0.3 * elevation.lift) * (enabled ? 1 : 0.4),
          ),
          Colors.white.withOpacity(0),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawPath(path, topLight);

    final bottomShade = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(0, 0.55),
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF000000).withOpacity(0),
          const Color(0xFF000000).withOpacity(_skin.bottomShade),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4;
    canvas.drawPath(path, bottomShade);

    // 5. especular — a argila é levemente úmida
    if (specular && enabled) {
      final sheenRect = Rect.fromCenter(
        center: Offset(size.width * 0.3, size.height * 0.16),
        width: size.width * (_light ? 0.82 : 0.68),
        height: size.height * (_light ? 0.44 : 0.36),
      );
      canvas.drawOval(
        sheenRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withOpacity(_skin.sheen),
              Colors.white.withOpacity(0),
            ],
          ).createShader(sheenRect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.restore();

    // 6. rim
    canvas.drawPath(
      path,
      Paint()
        ..color = _skin.rim.withOpacity(enabled ? (_light ? 0.5 : 0.9) : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // 7. foco
    if (focused) {
      final ringRect = rect.inflate(3);
      canvas.drawPath(
        ClayShape.squircle(ringRect, radius + 3),
        Paint()
          ..color = ClayPalette.celadon.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClaySurfacePainter old) =>
      old.kind != kind ||
      old.radius != radius ||
      old.press != press ||
      old.hovered != hovered ||
      old.focused != focused ||
      old.enabled != enabled ||
      old.elevation != elevation ||
      old.tint != tint ||
      old.tintStrength != tintStrength ||
      old.glow != glow ||
      old.strokeWidth != strokeWidth ||
      old.specular != specular ||
      old.body != body;
}

/// A superfície de argila: tudo o que tem material no app passa por aqui.
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.child,
    this.kind = ClayMaterialKind.obsidian,
    this.radius = ClayRadii.card,
    this.elevation = ClayElevation.l1,
    this.padding = const EdgeInsets.all(ClaySpace.md),
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.tint,
    this.glow,
    this.pressable = true,
    this.semanticLabel,
    this.tooltip,
    this.alignment,
    this.specular = true,
    this.body,
  });

  final Widget child;
  final ClayMaterialKind kind;
  final double radius;
  final ClayElevation elevation;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool selected;
  final Color? tint;
  final Color? glow;
  final bool pressable;
  final String? semanticLabel;
  final String? tooltip;
  final AlignmentGeometry? alignment;
  final bool specular;
  final Gradient? body;

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tint ?? (selected ? ClayPalette.kiln : null);
    final strength = selected ? 1.0 : (tint != null ? 1.0 : 0.0);

    Widget surfaceBody({
      required double press,
      required bool hovered,
      required bool focused,
    }) {
      return CustomPaint(
        painter: ClaySurfacePainter(
          kind: kind,
          radius: radius,
          press: press,
          hovered: hovered,
          focused: focused,
          enabled: enabled,
          elevation: elevation,
          tint: effectiveTint,
          tintStrength: strength,
          glow: glow,
          specular: specular,
          body: body,
        ),
        child: Padding(
          padding: padding,
          child: Align(
            alignment: alignment ?? Alignment.center,
            child: child,
          ),
        ),
      );
    }

    Widget surface = pressable
        ? ClayPressable(
            enabled: enabled,
            onTap: onTap,
            onLongPress: onLongPress,
            semanticLabel: semanticLabel,
            tooltip: tooltip,
            builder: (context, state) => surfaceBody(
              press: state.press,
              hovered: state.hovered,
              focused: state.focused,
            ),
          )
        : surfaceBody(press: 0, hovered: false, focused: false);

    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }
    return surface;
  }
}

/// Recorte em squircle para imagens e grades — o conteúdo herda a mesma
/// geometria da massa, senão a foto “vaza” do material.
class ClayClip extends StatelessWidget {
  const ClayClip({
    super.key,
    required this.child,
    this.radius = ClayRadii.card,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _SquircleClipper(radius),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SquircleClipper extends CustomClipper<Path> {
  _SquircleClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) =>
      ClayShape.squircle(Offset.zero & size, radius);

  @override
  bool shouldReclip(covariant _SquircleClipper oldClipper) =>
      oldClipper.radius != radius;
}
