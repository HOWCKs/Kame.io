import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

enum CaptureMode { foto, video }

/// Barra de controle da câmera no estilo "notch": cartão branco arredondado
/// com um recorte côncavo circular no topo, onde o obturador fica encaixado
/// metade para fora, com glow colorido — mesma linguagem visual das
/// referências enviadas pelo usuário.
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

  /// Geometria pública para o shape, o FAB e os testes ficarem de acordo.
  static const double barHeight = 96;
  static const double cornerRadius = 28;
  static const double notchRadius = 52;
  static const double fabRadius = 40; // diâmetro 80, contando o anel branco

  static const Color barColor = Color(0xFFF4F5F7);
  static const Color idleGrey = Color(0xFF63697A);
  static const Color accent = Color(0xFFE8384F);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: barHeight + fabRadius,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // O cartão branco com o recorte côncavo.
          Positioned(
            left: 0,
            right: 0,
            top: fabRadius,
            bottom: 0,
            child: PhysicalShape(
              clipper: const ShapeBorderClipper(shape: NotchedBarShape()),
              color: barColor,
              shadowColor: const Color(0x66000000),
              elevation: 18,
              child: _buildItems(),
            ),
          ),
          // Glow roxo/azul vazando do notch, por cima do cartão.
          Positioned(
            left: 0,
            right: 0,
            top: fabRadius - 75,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x807C4DFF),
                        Color(0x475865FF),
                        Color(0x00000000),
                      ],
                      stops: [0.30, 0.55, 0.78],
                    ),
                  ),
                ),
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
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
        SizedBox(width: notchRadius * 2 - 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
                selectedColor: const Color(0xFFF5A623),
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

class _BarAction extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : NotchedCameraBar.idleGrey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: NotchedCameraBar.accent.withValues(alpha: 0.12),
        child: SizedBox(
          width: 58,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('kame-shutter'),
      onTap: onTap,
      child: Container(
        width: NotchedCameraBar.fabRadius * 2,
        height: NotchedCameraBar.fabRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF7F8FA), // anel branco
          boxShadow: [
            BoxShadow(
              color: const Color(0x667C4DFF),
              blurRadius: 26,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: recording ? 30 : 64,
            height: recording ? 30 : 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(recording ? 9 : 40),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF5A6B), Color(0xFFE11D3C)],
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
