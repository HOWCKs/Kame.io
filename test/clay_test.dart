import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/theme/kame_theme.dart';
import 'package:kame_io/widgets/clay.dart';
import 'package:kame_io/widgets/clay_morph.dart';

void nullFn() {}

Widget _wrap(Widget child) => MaterialApp(
      theme: KameTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ClayTokens', () {
    test('a paleta de matéria é estável', () {
      expect(ClayTokens.clay, const Color(0xFFFF8355));
      expect(ClayTokens.violet, const Color(0xFF9A87FF));
      expect(KameTokens.primary, ClayTokens.clay);
      expect(KameTokens.background, ClayTokens.night);
    });

    test('luz e sombra derivam da cor base', () {
      final base = ClayTokens.clay;
      expect(ClayTokens.lighten(base), isNot(base));
      expect(ClayTokens.darken(base), isNot(base));
      expect(ClayTokens.darken(base, 0), base);
    });
  });

  group('ClaySurface', () {
    testWidgets('empilha a face sobre a lateral extrudada', (tester) async {
      // árvore mínima: só os DecoratedBox do próprio componente
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ClaySurface(
            color: ClayTokens.clay,
            depth: 8,
            child: Text('matéria'),
          ),
        ),
      );

      expect(find.text('matéria'), findsOneWidget);
      // face + lateral = dois DecoratedBox, o segundo deslocado para baixo
      expect(find.byType(DecoratedBox), findsNWidgets(2));
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(transform.offset, const Offset(0, 8));
    });
  });

  group('ClayButton', () {
    testWidgets('mostra o rótulo e responde ao toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(ClayButton(
          label: 'Capturar',
          icon: Icons.photo_camera_outlined,
          onTap: () => taps++,
        )),
      );

      expect(find.text('Capturar'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

      await tester.tap(find.text('Capturar'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('cabe em largura limitada sem estourar', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 160,
          child: ClayButton(label: 'Importar fotos', onTap: nullFn),
        )),
      );
      expect(find.text('Importar fotos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ClayMorph', () {
    testWidgets('pinta o núcleo de argila sem estourar', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 200,
          height: 200,
          child: ClayMorph(size: 140, color: ClayTokens.violet),
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(ClayMorph), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      // desmonta para encerrar o controlador (senão o timer fica pendente)
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();
    });
  });
}
