import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/widgets/notched_camera_bar.dart';

void main() {
  group('NotchedBarShape', () {
    const shape = NotchedBarShape();
    const rect = Rect.fromLTWH(0, 0, 360, 96);
    final path = shape.getOuterPath(rect);

    test('topo reto fora do notch fica dentro do path', () {
      expect(path.contains(const Offset(40, 10)), isTrue);
      expect(path.contains(const Offset(320, 10)), isTrue);
    });

    test('recorte côncavo exclui o centro do topo', () {
      // Centro do notch em (180, 0), raio 52: pontos dentro do círculo
      // pertencem ao vão, não ao cartão.
      expect(path.contains(const Offset(180, 10)), isFalse);
      expect(path.contains(const Offset(180, 40)), isFalse);
      // Logo abaixo do raio do notch o cartão volta a existir.
      expect(path.contains(const Offset(180, 60)), isTrue);
    });

    test('cantos arredondados recortam os vértices', () {
      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(const Offset(30, 4)), isTrue);
      expect(path.contains(const Offset(2, 92)), isFalse);
      expect(path.contains(const Offset(358, 92)), isFalse);
      expect(path.contains(const Offset(330, 92)), isTrue);
    });
  });

  group('NotchedCameraBar', () {
    Widget wrap({
      CaptureMode mode = CaptureMode.foto,
      bool recording = false,
      FlashMode flash = FlashMode.off,
      ValueChanged<CaptureMode>? onMode,
      VoidCallback? onShutter,
      VoidCallback? onConfig,
    }) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NotchedCameraBar(
              mode: mode,
              recording: recording,
              flash: flash,
              onModeChanged: onMode ?? (_) {},
              onShutter: onShutter ?? () {},
              onFlip: () {},
              onFlash: () {},
              onConfig: onConfig ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('exibe os cinco rótulos das referências', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      for (final label in ['Foto', 'Vídeo', 'Virar', 'Flash', 'Config.']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('tocar em Vídeo reporta o modo video', (tester) async {
      CaptureMode? changed;
      await tester.pumpWidget(wrap(onMode: (m) => changed = m));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vídeo'));
      await tester.pumpAndSettle();
      expect(changed, CaptureMode.video);
    });

    testWidgets('obturador dispara onShutter', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(onShutter: () => taps++));
      await tester.pumpAndSettle();

      // O círculo vermelho interno do FAB.
      await tester.tap(find.byKey(const ValueKey('kame-shutter')));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('flash ligado troca o ícone de raio', (tester) async {
      await tester.pumpWidget(wrap(flash: FlashMode.torch));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsNothing);
    });

    testWidgets('gravando, o obturador vira quadrado de stop', (tester) async {
      await tester.pumpWidget(wrap(recording: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final stop = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final constraints = stop.constraints;
      // O AnimatedContainer do stop usa width 30 quando gravando.
      expect(constraints?.maxWidth, 30);
    });
  });
}
