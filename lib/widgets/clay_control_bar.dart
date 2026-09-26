import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../icons/clay_glyphs.dart';
import '../shape/clay_squircle.dart';
import '../theme/clay_tokens.dart';
import 'clay_controls.dart';
import 'clay_surface.dart';

/// Modo de captura.
enum CaptureMode { foto, video }

/// A barra de controle do Kame.io.
///
/// Substitui a antiga barra “notch”. A silhueta continua reconhecível — o
/// obturador ainda nasce no topo, metade para fora — mas a lógica construtiva
/// se inverteu: antes a massa era **recortada** para abrir espaço; agora ela
/// **cresce** numa cúpula para receber a peça. Um recorte é uma ausência, uma
/// cúpula é matéria. Essa é a diferença entre decorar e representar.
class ClayControlBar extends StatelessWidget {
  const ClayControlBar({
    super.key,
    required this.mode,
    required this.recording,
    required this.flash,
    required this.ready,
    required this.pulse,
    required this.onModeChanged,
    required this.onShutter,
    required this.onFlip,
    required this.onFlash,
    required this.onSettings,
  });

  final CaptureMode mode;
  final bool recording;
  final FlashMode flash;
  final bool ready;
  final int pulse;
  final ValueChanged<CaptureMode> onModeChanged;
  final VoidCallback onShutter;
  final VoidCallback onFlip;
  final VoidCallback onFlash;
  final VoidCallback onSettings;

  /// Geometria pública — o shape, o obturador e os testes leem daqui.
  static const double barHeight = 78;
  static const double cornerRadius = 30;
  static const double domeRadius = 36;
  static const double puckDiameter = 56;
  static const double shadowPad = 14;

  static double get totalHeight => domeRadius + barHeight + shadowPad;

  @override
  Widget build(BuildContext context) {
    final flashOn = flash != FlashMode.off;
    final torch = flash == FlashMode.torch;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Massa da barra (cúpula incluída).
          Positioned.fill(
            child: const CustomPaint(
              painter: ClayBarPainter(
                cornerRadius: cornerRadius,
                domeRadius: domeRadius,
                top: domeRadius,
                height: barHeight,
              ),
            ),
          ),
          // Conteúdo, alinhado ao corpo da barra (abaixo da cúpula).
          Positioned(
            left: 0,
            right: 0,
            top: domeRadius,
            height: barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ClaySpace.sm + 2,
                vertical: ClaySpace.sm + 2,
              ),
              child: Row(
                children: <Widget>[
                  Flexible(
                    flex: 2,
                    child: ClayVein(
                      height: 58,
                      selected: mode.index,
                      semanticLabel: 'Modo de captura',
                      onChanged: (index) =>
                          onModeChanged(CaptureMode.values[index]),
                      segments: <ClaySegment>[
                        ClaySegment(
                          label: 'Foto',
                          semanticLabel: 'Modo foto',
                          glyph: ClayGlyphCache.of(
                            mode == CaptureMode.foto
                                ? 'aperture-closed'
                                : 'aperture-open',
                            () => ClayGlyphs.aperture(
                              blade: mode == CaptureMode.foto ? 0.62 : 1,
                            ),
                          ),
                        ),
                        ClaySegment(
                          label: 'Vídeo',
                          semanticLabel: 'Modo vídeo',
                          glyph: ClayGlyphCache.of('reel', ClayGlyphs.reel),
                        ),
                      ],
                    ),
                  ),
                  // Vão da cúpula: a matéria se abre para o obturador.
                  const SizedBox(width: 56),
                  Flexible(
                    flex: 3,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: ClayIconButton(
                            width: double.infinity,
                            height: 58,
                            label: 'Virar',
                            enabled: ready,
                            glyph: ClayGlyphCache.of(
                              'flip',
                              ClayGlyphs.flipLens,
                            ),
                            onTap: onFlip,
                            tooltip: 'Trocar de câmera',
                          ),
                        ),
                        const SizedBox(width: ClaySpace.xs),
                        Expanded(
                          child: ClayIconButton(
                            width: double.infinity,
                            height: 58,
                            label: 'Flash',
                            selected: flashOn,
                            tone: ClayPalette.ochre,
                            enabled: ready,
                            glyph: ClayGlyphCache.of(
                              torch ? 'bolt-torch' : 'bolt',
                              () => ClayGlyphs.bolt(rays: torch),
                            ),
                            onTap: onFlash,
                            tooltip: flashOn ? 'Ajustar flash' : 'Ligar flash',
                          ),
                        ),
                        const SizedBox(width: ClaySpace.xs),
                        Expanded(
                          child: ClayIconButton(
                            width: double.infinity,
                            height: 58,
                            label: 'Ajustes',
                            glyph: ClayGlyphCache.of('dial', ClayGlyphs.dial),
                            onTap: onSettings,
                            tooltip: 'Ajustes do Kame.io',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Obturador: centrado na borda superior da barra.
          Positioned(
            left: 0,
            right: 0,
            top: domeRadius - puckDiameter / 2,
            child: Center(
              child: ClayShutter(
                key: const ValueKey<String>('kame-shutter'),
                recording: recording,
                ready: ready,
                pulse: pulse,
                diameter: puckDiameter,
                onTap: onShutter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintor da barra: porcelana com cúpula.
///
/// Repete a receita de luz do [ClaySurfacePainter] porque a barra precisa de
/// um caminho customizado (cúpula + cantos contínuos) que nenhum
/// `ShapeBorder` genérico entrega com a mesma qualidade de silhueta.
class ClayBarPainter extends CustomPainter {
  const ClayBarPainter({
    required this.cornerRadius,
    required this.domeRadius,
    required this.top,
    required this.height,
  });

  final double cornerRadius;
  final double domeRadius;
  final double top;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final barRect = Rect.fromLTWH(0, top, size.width, height);
    final path = ClayShape.domeBar(
      rect: barRect,
      corner: cornerRadius,
      domeRadius: domeRadius,
    );
    final bounds = path.getBounds();

    // 1. sombra — a barra flutua sobre o viewfinder.
    canvas.drawPath(
      path.shift(const Offset(0, 12)),
      Paint()
        ..color = const Color(0xFF000000).withOpacity(0.46)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // 2. corpo
    canvas.drawPath(
      path,
      Paint()..shader = ClayPalette.porcelainBody.createShader(bounds),
    );

    canvas
      ..save()
      ..clipPath(path);

    // 3. realce interno no topo
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: const Alignment(0, 0.3),
          colors: <Color>[
            Colors.white.withOpacity(0.7),
            Colors.white.withOpacity(0),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );

    // 4. sombra interna embaixo
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(0, 0.62),
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF000000).withOpacity(0),
            const Color(0xFF000000).withOpacity(0.18),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6,
    );

    // 5. especular longo — porcelana polida
    final sheen = Rect.fromLTWH(
      bounds.left + bounds.width * 0.06,
      bounds.top + bounds.height * 0.08,
      bounds.width * 0.5,
      bounds.height * 0.34,
    );
    canvas.drawOval(
      sheen,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withOpacity(0.45),
            Colors.white.withOpacity(0),
          ],
        ).createShader(sheen)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.restore();

    // 6. rim
    canvas.drawPath(
      path,
      Paint()
        ..color = ClayPalette.porcelainDeep.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant ClayBarPainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.domeRadius != domeRadius ||
      oldDelegate.top != top ||
      oldDelegate.height != height;
}
