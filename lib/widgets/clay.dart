import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Componentes de matéria do Kame.io.
///
/// [ClaySurface] — superfície extrudada: uma face com gradiente e luz de
/// cima, apoiada sobre uma "lateral" mais escura deslocada para baixo. O
/// volume vem dessa pilha, não de borda grossa.
/// ═══════════════════════════════════════════════════════════════════════
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.child,
    this.color,
    this.radius = ClayTokens.r,
    this.depth = ClayTokens.depth,
    this.padding,
    this.margin,
    this.shadows,
    this.width,
    this.height,
    this.align,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final AlignmentGeometry? align;

  @override
  Widget build(BuildContext context) {
    final base = color ?? ClayTokens.nightSoft;
    final shape = BorderRadius.circular(radius);

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // lateral da matéria (o quanto o objeto "afunda" na tela)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, depth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      ClayTokens.darken(base, 0.28),
                      ClayTokens.darken(base, 0.52),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // face iluminada
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  ClayTokens.lighten(base, 0.16),
                  base,
                  ClayTokens.darken(base, 0.14),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
              boxShadow: shadows ?? ClayTokens.liftSm,
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: align == null ? child : Align(alignment: align!, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painel de vidro: desfoca o que está atrás e deixa a informação flutuar.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = ClayTokens.rLg,
    this.padding,
    this.margin,
    this.blur = ClayTokens.glassBlur,
    this.color,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: ClayTokens.lift,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color ?? ClayTokens.glassStrong,
              borderRadius: BorderRadius.circular(radius),
              border: border
                  ? Border.all(color: ClayTokens.glassRim)
                  : null,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(ClayTokens.gap),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de argila: cede ao toque (escala com peso) e volta com overshoot.
class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.foreground,
    this.expand = false,
    this.radius = ClayTokens.rPill,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final bool expand;
  final double radius;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? ClayTokens.clay;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, size: 19),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );

    return SizedBox(
      width: widget.expand ? double.infinity : null,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: ClayTokens.fast,
          curve: ClayTokens.spring,
          child: ClaySurface(
            color: base,
            radius: widget.radius,
            depth: _pressed ? 3 : 7,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            shadows: ClayTokens.glowClay,
            child: DefaultTextStyle(
              style: TextStyle(
                color: widget.foreground ?? const Color(0xFFFFF7F2),
              ),
              child: IconTheme(
                data: IconThemeData(color: widget.foreground ?? const Color(0xFFFFF7F2)),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão circular de argila (ícone).
class ClayIconButton extends StatefulWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 46,
    this.color = ClayTokens.nightSoft,
    this.iconColor = ClayTokens.ink,
    this.selected = false,
    this.selectedColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final Color color;
  final Color iconColor;
  final bool selected;
  final Color? selectedColor;

  @override
  State<ClayIconButton> createState() => _ClayIconButtonState();
}

class _ClayIconButtonState extends State<ClayIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.selectedColor ?? ClayTokens.clay;
    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: ClayTokens.fast,
        curve: ClayTokens.spring,
        child: ClaySurface(
          color: widget.selected ? accent : widget.color,
          radius: ClayTokens.rPill,
          depth: _pressed ? 3 : 6,
          width: widget.size,
          height: widget.size,
          align: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.size * 0.44,
            color: widget.selected
                ? const Color(0xFFFFF7F2)
                : (widget.selected ? accent : widget.iconColor),
          ),
        ),
      ),
    );

    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}

/// Pílula de estado (gravação, contador, selos) — pequena, de matéria macia.
class ClayPill extends StatelessWidget {
  const ClayPill({
    super.key,
    required this.child,
    this.color = ClayTokens.nightSoft,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      color: color,
      radius: ClayTokens.rPill,
      depth: 4,
      padding: padding,
      shadows: ClayTokens.liftSm,
      child: child,
    );
  }
}
