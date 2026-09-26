import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/widgets/clay_control_bar.dart';

void main() {
  group('ClayShape.domeBar', () {
    const rect = Rect.fromLTWH(0, 36, 360, 78);
    final path = ClayShape.domeBar(
      rect: rect,
      corner: 30,
      domeRadius: 36,
    );

    test('a cúpula soma matéria acima da borda superior', () {
      // Centro do topo, 20 px acima: dentro da cúpula.
      expect(path.contains(const Offset(180, 20)), isTrue);
      // Fora do raio da cúpula, na mesma altura: fora da massa.
      expect(path.contains(const Offset(60, 20)), isFalse);
    });

    test('o corpo da barra existe abaixo do topo', () {
      expect(path.contains(const Offset(180, 90)), isTrue);
      expect(path.contains(const Offset(30, 90)), isTrue);
    });

    test('cantos contínuos recortam os vértices', () {
      expect(path.contains(const Offset(1, 37)), isFalse);
      expect(path.contains(const Offset(40, 40)), isTrue);
      expect(path.contains(const Offset(359, 113)), isFalse);
    });
  });

  group('ClayControlBar', () {
    Widget wrap({
      CaptureMode mode = CaptureMode.foto,
      bool recording = false,
      FlashMode flash = FlashMode.off,
      ValueChanged<CaptureMode>? onMode,
      VoidCallback? onShutter,
      VoidCallback? onFlip,
      VoidCallback? onFlash,
      VoidCallback? onSettings,
    }) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: ClayControlBar(
                mode: mode,
                recording: recording,
                flash: flash,
                ready: true,
                pulse: 0,
                onModeChanged: onMode ?? (_) {},
                onShutter: onShutter ?? () {},
                onFlip: onFlip ?? () {},
                onFlash: onFlash ?? () {},
                onSettings: onSettings ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('exibe os cinco rótulos de função', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      for (final label in <String>['Foto', 'Vídeo', 'Virar', 'Flash', 'Ajustes']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('tocar em Vídeo troca o modo', (tester) async {
      CaptureMode? changed;
      await tester.pumpWidget(wrap(onMode: (m) => changed = m));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vídeo'));
      await tester.pumpAndSettle();
      expect(changed, CaptureMode.video);
    });

    testWidgets('obturador dispara a captura', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(onShutter: () => taps++));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('kame-shutter')));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('os três controles da direita respondem', (tester) async {
      var flip = 0;
      var flash = 0;
      var settings = 0;
      await tester.pumpWidget(
        wrap(
          onFlip: () => flip++,
          onFlash: () => flash++,
          onSettings: () => settings++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Virar'));
      await tester.tap(find.text('Flash'));
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(flip, 1);
      expect(flash, 1);
      expect(settings, 1);
    });

    testWidgets('gravando, o obturador encolhe e fala “parar”', (tester) async {
      await tester.pumpWidget(wrap(recording: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.bySemanticsLabel('Parar gravação'),
        findsOneWidget,
      );
    });

    testWidgets('câmera indisponível desabilita obturador, virar e flash',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ClayControlBar(
                mode: CaptureMode.foto,
                recording: false,
                flash: FlashMode.off,
                ready: false,
                pulse: 0,
                onModeChanged: (_) {},
                onShutter: () => taps++,
                onFlip: () => taps++,
                onFlash: () => taps++,
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('kame-shutter')));
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'controles frios não podem agir');
    });
  });
}
