import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/icons/clay_glyphs.dart';
import 'package:kame_io/motion/clay_motion.dart';
import 'package:kame_io/theme/clay_theme.dart';
import 'package:kame_io/theme/clay_tokens.dart';
import 'package:kame_io/widgets/clay_controls.dart';
import 'package:kame_io/widgets/clay_surface.dart';

void main() {
  group('glifos', () {
    final all = <String, List<ClayStroke>>{
      'abertura': ClayGlyphs.aperture(),
      'carretel': ClayGlyphs.reel(),
      'virar': ClayGlyphs.flipLens(),
      'raio': ClayGlyphs.bolt(),
      'raio aceso': ClayGlyphs.bolt(rays: true),
      'mostrador': ClayGlyphs.dial(),
      'grade': ClayGlyphs.grid(),
      'pilha': ClayGlyphs.stack(),
      'onda': ClayGlyphs.wave(),
      'bandeja': ClayGlyphs.tray(),
      'timer': ClayGlyphs.timer(),
      'fechar': ClayGlyphs.close(),
      'voltar': ClayGlyphs.back(),
      'câmera off': ClayGlyphs.cameraOff(),
      'confirmar': ClayGlyphs.check(),
      'compartilhar': ClayGlyphs.share(),
      'excluir': ClayGlyphs.trash(),
      'adicionar': ClayGlyphs.plus(),
      'tentar': ClayGlyphs.retry(),
      'arrastar': ClayGlyphs.drag(),
      'marca': ClayGlyphs.mark(),
      'velocidade': ClayGlyphs.speed(),
      'pulso': ClayGlyphs.pulse(),
    };

    test('todo glifo tem traço dentro da caixa de 24', () {
      all.forEach((name, glyph) {
        expect(glyph, isNotEmpty, reason: name);
        for (final stroke in glyph) {
          final bounds = stroke.path.getBounds();
          expect(bounds, isNotNull, reason: name);
          expect(bounds.left, greaterThanOrEqualTo(-0.6), reason: name);
          expect(bounds.top, greaterThanOrEqualTo(-0.6), reason: name);
          expect(bounds.right, lessThanOrEqualTo(24.6), reason: name);
          expect(bounds.bottom, lessThanOrEqualTo(24.6), reason: name);
        }
      });
    });

    test('o cache devolve a mesma identidade para a mesma chave', () {
      final a = ClayGlyphCache.of('teste', ClayGlyphs.reel);
      final b = ClayGlyphCache.of('teste', ClayGlyphs.reel);
      expect(identical(a, b), isTrue);
      expect(identical(a, ClayGlyphs.reel()), isFalse);
    });

    test('a íris fecha quando o modo foto está ativo', () {
      final aberta = ClayGlyphs.aperture(blade: 1);
      final fechada = ClayGlyphs.aperture(blade: 0.62);
      expect(
        fechada.last.path.getBounds().width,
        lessThan(aberta.last.path.getBounds().width),
      );
    });
  });

  group('tema', () {
    testWidgets('Material 3 escuro com os tokens de argila', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ClayTheme.dark(), home: const Scaffold(body: Text('ok'))),
      );
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.text('ok')));
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, ClayPalette.kiln);
      expect(theme.scaffoldBackgroundColor, ClayPalette.abyss);
      expect(theme.textTheme.bodyMedium?.fontFamily, ClayType.family);
    });
  });

  group('movimento', () {
    testWidgets('sem escopo, a duração é a cheia', (tester) async {
      late ClayMotionData data;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              data = ClayMotionScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(data.reduced, isFalse);
      expect(data.d(const Duration(milliseconds: 400)).inMilliseconds, 400);
    });

    testWidgets('movimento reduzido encolhe as durações e lineariza a curva',
        (tester) async {
      late ClayMotionData data;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                data = ClayMotionScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(data.reduced, isTrue);
      expect(data.haptics, isFalse);
      expect(data.d(const Duration(milliseconds: 400)).inMilliseconds, lessThan(400));
      expect(data.curve(ClayCurves.squish), Curves.linear);
    });
  });

  group('superfície', () {
    Future<void> pumpSurface(
      WidgetTester tester, {
      required bool enabled,
      required VoidCallback? onTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ClaySurface(
                width: 120,
                height: 56,
                enabled: enabled,
                onTap: onTap,
                semanticLabel: 'Ação de teste',
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('habilitada, responde ao toque', (tester) async {
      var taps = 0;
      await pumpSurface(tester, enabled: true, onTap: () => taps++);
      await tester.tap(find.bySemanticsLabel('Ação de teste'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('desabilitada, não responde', (tester) async {
      var taps = 0;
      await pumpSurface(tester, enabled: false, onTap: () => taps++);
      await tester.tap(find.bySemanticsLabel('Ação de teste'));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('foco por teclado é visível e aciona', (tester) async {
      var taps = 0;
      await pumpSurface(tester, enabled: true, onTap: () => taps++);

      final focus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Focus),
        ),
      );
      expect(focus.canRequestFocus, isTrue);
      focus.focusNode?.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('chave de forno', () {
    testWidgets('alterna e avisa o valor', (tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ClaySwitch(
                value: value,
                semanticLabel: 'Manter as formas',
                onChanged: (next) => value = next,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Manter as formas'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });
  });

  group('veio', () {
    testWidgets('o segmento escolhido é o único selecionado', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return ClayVein(
                      selected: selected,
                      semanticLabel: 'Modo de captura',
                      onChanged: (index) => setState(() => selected = index),
                      segments: <ClaySegment>[
                        ClaySegment(label: 'Foto', glyph: ClayGlyphs.aperture()),
                        ClaySegment(label: 'Vídeo', glyph: ClayGlyphs.reel()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vídeo'));
      await tester.pumpAndSettle();
      expect(selected, 1);
    });
  });
}
