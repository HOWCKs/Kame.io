import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/theme/clay_tokens.dart';
import 'package:kame_io/widgets/clay_field.dart';

void main() {
  const size = Size(320, 220);

  Path surfaceOf(List<ClaySample> samples, {int angles = 48}) =>
      ClayFieldPainter.surfaceFor(samples, size, angles: angles);

  test('um bloco isolado tem contorno no raio exato do campo', () {
    const center = Offset(160, 110);
    const radius = 40.0;
    final bounds = surfaceOf(<ClaySample>[const ClaySample(center, radius)])
        .getBounds();

    // Superfície de Σ r²/d² = 1 com um único bloco => d = r.
    expect(bounds.center.dx, closeTo(center.dx, 1.5));
    expect(bounds.center.dy, closeTo(center.dy, 1.5));
    expect(bounds.width, closeTo(radius * 2, radius * 0.1));
    expect(bounds.height, closeTo(radius * 2, radius * 0.1));
  });

  test('blocos próximos se fundem: o vale do meio é preenchido', () {
    final bounds = surfaceOf(<ClaySample>[
      const ClaySample(Offset(140, 110), 34),
      const ClaySample(Offset(180, 110), 34),
    ]).getBounds();

    // Dois círculos independentes dariam largura 2r + d = 108 com um vale no
    // meio. O metaball cria o “pescoço”: a silhueta fica contínua.
    expect(bounds.width, greaterThan(34 * 2 + 40 - 14));
    expect(bounds.width, lessThan(34 * 2 + 40 + 46));
  });

  test('blocos distantes viram ilhas preservadas na união', () {
    final path = surfaceOf(<ClaySample>[
      const ClaySample(Offset(50, 110), 18),
      const ClaySample(Offset(280, 110), 18),
    ]);
    final bounds = path.getBounds();

    // Se a união engolisse uma das ilhas, a largura cairia pela metade.
    expect(bounds.width, greaterThan(200));
    expect(path.contains(const Offset(50, 110)), isTrue);
    expect(path.contains(const Offset(280, 110)), isTrue);
    expect(path.contains(const Offset(165, 110)), isFalse);
  });

  test('a amostragem é determinística entre quadros', () {
    final samples = <ClaySample>[
      const ClaySample(Offset(120, 90), 30),
      const ClaySample(Offset(190, 130), 26),
    ];
    expect(surfaceOf(samples).getBounds(), equals(surfaceOf(samples).getBounds()));
  });

  test('a qualidade baixa ainda fecha a silhueta', () {
    final bounds = surfaceOf(
      <ClaySample>[const ClaySample(Offset(160, 110), 50)],
      angles: 24,
    ).getBounds();
    expect(bounds.width, closeTo(100, 12));
  });

  test('bloco maior que a caixa não estoura a memória nem o caminho', () {
    final bounds = surfaceOf(<ClaySample>[
      const ClaySample(Offset(160, 110), 400),
    ]).getBounds();
    expect(bounds.width, lessThan(size.longestSide * 4));
  });

  test('o pintor reporta repintura (campo é animado)', () {
    final painter = ClayFieldPainter(
      samples: const <ClaySample>[ClaySample(Offset(160, 110), 40)],
      light: const Offset(-0.6, -0.75),
      tone: ClayPalette.kiln,
    );
    expect(painter.shouldRepaint(painter), isTrue);
  });
}
