import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';

enum CaptureMode { foto, video }

/// Barra de controle da câmera no estilo "notch": cartão de argila clara com
/// um recorte côncavo circular no topo, onde o obturador fica encaixado
/// metade para fora, com brilho de matéria — a mesma geometria das
/// referências, agora com a linguagem CLAY MORPHIST.
///
/// A geometria (altura, raio do notch, recorte) é pública para o shape, o
/// obturador e os testes ficarem de acordo.
class NotchedCameraBar extends StatelessWidget {
  const NotchedCameraBar({
    super.key,
    required this.mode,
    required this.recording,
    required this.flash,
    required this.onModeChanged,
    required this.onShutter,
    required this.onFlip,
    required this.onFlash,
    required this.onConfig,
  });

  final CaptureMode mode;
  final bool recording;
  final FlashMode flash;
  final ValueChanged<CaptureMode> onModeChanged;
  final VoidCallback onShutter;
  final VoidCallback onFlip;
  final VoidCallback onFlash;
  final VoidCallback onConfig;

  static const double barHeight = 96;
  static const double cornerRadius = 28;
  static const double notchRadius = 52;
  static const double fabRadius = 40; // diâmetro 80, contando o anel

  /// Porcelana morna — a matéria clara da barra.
  static const Color barColor = Color(0xFFF7F1EA);
  static const Color idleGrey = Color(0xFF6E6478);
  static const Color accent = Color(0xFFFF4D5E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: barHeight + fabRadius,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Halo de matéria vazando do notch, atrás do cartão.
          Positioned(
            left: 0,
            right: 0,
            top: fabRadius - 78,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  width: 158,
                  height: 158,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        Color(0x99FF9E6B),
                        Color(0x666A5BFF),
                        Color(0x00000000),
                      ],
                      stops: <double>[0.28, 0.56, 0.78],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // O cartão claro com o recorte côncavo.
          Positioned(
            left: 0,
            right: 0,
            top: fabRadius,
            bottom: 0,
            child: PhysicalShape(
              clipper: const ShapeBorderClipper(shape: NotchedBarShape()),
              color: barColor,
              shadowColor: const Color(0x99000000),
              elevation: 18,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFFFFBF6), Color(0xFFEDE2D6)],
                  ),
                ),
                child: _buildItems(),
              ),
            ),
          ),
          // Obturador.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(child: _Shutter(recording: recording, onTap: onShutter)),
          ),
        ],
      ),
    );
  }

  Widget _buildItems() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _BarAction(
                icon: Icons.photo_camera_outlined,
                label: 'Foto',
                selected: mode == CaptureMode.foto,
                onTap: () => onModeChanged(CaptureMode.foto),
              ),
              _BarAction(
                icon: Icons.videocam_outlined,
                label: 'Vídeo',
                selected: mode == CaptureMode.video,
                onTap: () => onModeChanged(CaptureMode.video),
              ),
            ],
          ),
        ),
        // Vão central do notch.
        const SizedBox(width: notchRadius * 2 - 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _BarAction(
                icon: Icons.flip_camera_android_outlined,
                label: 'Virar',
                onTap: onFlip,
              ),
              _BarAction(
                icon: flash == FlashMode.off
                    ? Icons.bolt_outlined
                    : Icons.flash_on_rounded,
                label: 'Flash',
                selected: flash != FlashMode.off,
                selectedColor: ClayTokens.sun,
                onTap: onFlash,
              ),
              _BarAction(
                icon: Icons.settings_outlined,
                label: 'Config.',
                onTap: onConfig,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ação da barra: pílula de argila que afunda quando selecionada.
class _BarAction extends StatefulWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.selectedColor = NotchedCameraBar.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color selectedColor;

  @override
  State<_BarAction> createState() => _BarActionState();
}

class _BarActionState extends State<_BarAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.selectedColor : NotchedCameraBar.idleGrey;
    final tint = widget.selected
        ? widget.selectedColor.withOpacity(0.18)
        : const Color(0x14000000);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(ClayTokens.rSm),
        splashColor: NotchedCameraBar.accent.withOpacity(0.12),
          child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: ClayTokens.fast,
          curve: ClayTokens.spring,
          child: SizedBox(
            width: 60,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // base neutra + tinta de seleção em camadas (sem
                // AnimatedContainer: o obturador é o único da barra)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ClayTokens.rSm),
                    color: const Color(0x0F000000),
                  ),
                ),
                AnimatedOpacity(
                  opacity: widget.selected ? 1 : 0,
                  duration: ClayTokens.smooth,
                  curve: ClayTokens.out,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ClayTokens.rSm),
                      color: tint,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: widget.selectedColor.withOpacity(0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(widget.icon, size: 23, color: color),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1,
                        fontWeight:
                            widget.selected ? FontWeight.w800 : FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Obturador: anel de porcelana + núcleo de matéria que amassa ao toque.
class _Shutter extends StatefulWidget {
  const _Shutter({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('kame-shutter'),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1,
        duration: ClayTokens.fast,
        curve: ClayTokens.spring,
        child: Container(
          width: NotchedCameraBar.fabRadius * 2,
          height: NotchedCameraBar.fabRadius * 2,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFFFDFB), Color(0xFFE9DCCD)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66FF7A45),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            // Único AnimatedContainer da barra: o núcleo do obturador
            // (círculo em repouso, quadrado de "stop" gravando).
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: widget.recording ? 30 : 64,
              height: widget.recording ? 30 : 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.recording ? 9 : 40),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFFF7A86), Color(0xFFD7263D)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x59D7263D),
                    blurRadius: widget.recording ? 10 : 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão arredondado com recorte côncavo no topo (o "notch" do obturador).
///
/// O centro do círculo do recorte fica exatamente no meio do topo do
/// retângulo, então o obturador — centrado nesse mesmo ponto — fica metade
/// para fora da barra.
class NotchedBarShape extends ShapeBorder {
  const NotchedBarShape({
    this.cornerRadius = NotchedCameraBar.cornerRadius,
    this.notchRadius = NotchedCameraBar.notchRadius,
  });

  final double cornerRadius;
  final double notchRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final cr = cornerRadius;
    final r = notchRadius;
    final center = Offset(rect.center.dx, rect.top);
    final d = cr * 2;

    final path = Path()
      ..moveTo(rect.left + cr, rect.top)
      ..lineTo(center.dx - r, rect.top)
      // Recorte côncavo: meia-volta por baixo do círculo do notch.
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(rect.right - cr, rect.top)
      ..arcTo(
        Rect.fromLTRB(rect.right - d, rect.top, rect.right, rect.top + d),
        -math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(rect.right, rect.bottom - cr)
      ..arcTo(
        Rect.fromLTRB(
            rect.right - d, rect.bottom - d, rect.right, rect.bottom),
        0,
        math.pi / 2,
        false,
      )
      ..lineTo(rect.left + cr, rect.bottom)
      ..arcTo(
        Rect.fromLTRB(rect.left, rect.bottom - d, rect.left + d, rect.bottom),
        math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(rect.left, rect.top + cr)
      ..arcTo(
        Rect.fromLTRB(rect.left, rect.top, rect.left + d, rect.top + d),
        math.pi,
        math.pi / 2,
        false,
      )
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder lerpTo(ShapeBorder? b, double t) => this;
}
