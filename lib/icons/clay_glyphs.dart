import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Um traço de um glifo: um caminho em espaço de 24×24 + como ele é pintado.
///
/// Os glifos do CLAY MORPHIST são **desenhados à mão em vetor**, não vindos de
/// uma fonte de ícones genérica. Cada um foi construído para representar a
/// função real que executa (abertura = foto, carretel = vídeo, mostrador =
/// ajustes), e todos compartilham a mesma régua: caixa de 24, traço 1.9,
/// pontas redondas. É essa régua comum que faz o conjunto parecer uma família.
class ClayStroke {
  const ClayStroke(
    this.path, {
    this.filled = false,
    this.width = 1.9,
    this.opacity = 1,
  });

  final Path path;

  /// Traços fechados podem ser preenchidos (o raio aceso, por exemplo).
  final bool filled;
  final double width;
  final double opacity;
}

/// Biblioteca de glifos.
///
/// Convenção: 0,0 no canto superior esquerdo, 24×24, nada encosta na borda
/// (margem óptica de ~3) para o glifo respirar dentro do botão.
abstract final class ClayGlyphs {
  // ── Captura ───────────────────────────────────────────────────────────────

  /// **Foto** — abertura de lente. O hexágono interno é a íris; quando o modo
  /// está ativo a íris “fecha” (ver [aperture] com `blades`).
  static List<ClayStroke> aperture({double blade = 1}) {
    const c = Offset(12, 12);
    final ring = Path()..addOval(Rect.fromCircle(center: c, radius: 8.6));
    final iris = Path();
    final hub = 5.2 * blade;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = Offset(12 + hub * math.cos(a), 12 + hub * math.sin(a));
      if (i == 0) {
        iris.moveTo(p.dx, p.dy);
      } else {
        iris.lineTo(p.dx, p.dy);
      }
    }
    iris.close();
    return <ClayStroke>[ClayStroke(ring), ClayStroke(iris)];
  }

  /// **Vídeo** — quadro de filme com play.
  static List<ClayStroke> reel() {
    final frame = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.4, 6.6, 12.2, 10.8),
          const Radius.circular(3.4),
        ),
      );
    final play = Path()
      ..moveTo(10.1, 9.7)
      ..lineTo(14.6, 12)
      ..lineTo(10.1, 14.3)
      ..close();
    return <ClayStroke>[ClayStroke(frame), ClayStroke(play, filled: false)];
  }

  /// **Virar** — lente girando sobre o próprio eixo.
  static List<ClayStroke> flipLens() {
    const c = Offset(12, 12);
    final lens = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 8.6, height: 6.6),
          const Radius.circular(2.6),
        ),
      );
    return <ClayStroke>[
      _arcWithHead(c, 8.6, math.pi * 1.16, math.pi * 0.62),
      _arcWithHead(c, 8.6, math.pi * 0.16, math.pi * 0.62),
      ClayStroke(lens),
    ];
  }

  /// **Flash** — centelha. Com `rays`, vira “lanterna”: a centelha
  /// irradiando continuamente.
  static List<ClayStroke> bolt({bool rays = false}) {
    final spark = Path()
      ..moveTo(13.8, 2.9)
      ..lineTo(6.4, 12.9)
      ..lineTo(10.8, 12.9)
      ..lineTo(9.9, 21.1)
      ..lineTo(17.6, 9.5)
      ..lineTo(13.1, 9.5)
      ..close();
    final strokes = <ClayStroke>[ClayStroke(spark, filled: false)];
    if (rays) {
      final beams = Path()
        ..moveTo(4.6, 3.4)
        ..lineTo(6.9, 5.7)
        ..moveTo(19.4, 3.4)
        ..lineTo(17.1, 5.7)
        ..moveTo(4.6, 20.6)
        ..lineTo(6.9, 18.3)
        ..moveTo(19.4, 20.6)
        ..lineTo(17.1, 18.3);
      strokes.add(ClayStroke(beams, width: 1.6, opacity: 0.9));
    }
    return strokes;
  }

  // ── Ajustes ───────────────────────────────────────────────────────────────

  /// **Ajustes** — mostrador de forno. Não é uma engrenagem: engrenagem virou
  /// rótulo genérico de “configurações”; um mostrador diz *dosar*, que é o que
  /// o usuário faz aqui.
  static List<ClayStroke> dial() {
    const c = Offset(12, 12);
    final scale = Path()
      ..addArc(Rect.fromCircle(center: c, radius: 8.4), math.pi * 0.86,
          math.pi * 1.28);
    final knob = Path()..addOval(Rect.fromCircle(center: c, radius: 5.2));
    final pointer = Path()
      ..moveTo(12, 12)
      ..lineTo(
          12 - 3.3 * math.cos(math.pi / 4), 12 - 3.3 * math.sin(math.pi / 4));
    final ticks = Path();
    for (final a in <double>[0.86, 1.18, 1.5, 1.82, 2.14]) {
      final t = math.pi * a;
      ticks.moveTo(12 + 9.8 * math.cos(t), 12 + 9.8 * math.sin(t));
      ticks.lineTo(12 + 11.4 * math.cos(t), 12 + 11.4 * math.sin(t));
    }
    return <ClayStroke>[
      ClayStroke(ticks, width: 1.5, opacity: 0.7),
      ClayStroke(scale),
      ClayStroke(knob),
      ClayStroke(pointer),
    ];
  }

  /// **Grade 3×3** — regra dos terços.
  static List<ClayStroke> grid() {
    final p = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.4, 3.4, 17.2, 17.2),
          const Radius.circular(3.2),
        ),
      )
      ..moveTo(9.13, 3.4)
      ..lineTo(9.13, 20.6)
      ..moveTo(14.87, 3.4)
      ..lineTo(14.87, 20.6)
      ..moveTo(3.4, 9.13)
      ..lineTo(20.6, 9.13)
      ..moveTo(3.4, 14.87)
      ..lineTo(20.6, 14.87);
    return <ClayStroke>[ClayStroke(p, width: 1.5)];
  }

  /// **Atlas** — três camadas de matéria empilhadas.
  static List<ClayStroke> stack() {
    Path bar(double y, double w) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4.2, y, w, 3.8),
          const Radius.circular(1.9),
        ),
      );
    return <ClayStroke>[
      ClayStroke(bar(15.6, 15.4)),
      ClayStroke(bar(10.1, 11.2)),
      ClayStroke(bar(4.6, 13.2)),
    ];
  }

  /// **Som** — onda.
  static List<ClayStroke> wave() {
    final p = Path();
    const bars = <double>[5.2, 4.4, 9.8, 13.4, 6.8];
    for (var i = 0; i < bars.length; i++) {
      final x = 5.2 + i * 3.4;
      p.moveTo(x, 12 - bars[i] / 2);
      p.lineTo(x, 12 + bars[i] / 2);
    }
    return <ClayStroke>[ClayStroke(p, width: 2.2)];
  }

  /// **Manter formas** — bandeja recebendo a peça.
  static List<ClayStroke> tray() {
    final p = Path()
      ..moveTo(12, 4.8)
      ..lineTo(12, 13.4)
      ..moveTo(9.3, 10.5)
      ..lineTo(12, 13.4)
      ..lineTo(14.7, 10.5)
      ..moveTo(5, 13.6)
      ..lineTo(5, 17.8)
      ..lineTo(19, 17.8)
      ..lineTo(19, 13.6);
    return <ClayStroke>[ClayStroke(p)];
  }

  // ── Sistema ───────────────────────────────────────────────────────────────

  /// **Timer** — mostrador de tempo.
  static List<ClayStroke> timer() {
    const c = Offset(12, 12);
    final p = Path()
      ..addOval(Rect.fromCircle(center: c, radius: 8.5))
      ..moveTo(12, 12)
      ..lineTo(12, 6.9)
      ..moveTo(12, 12)
      ..lineTo(16.2, 13.4);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Fechar**.
  static List<ClayStroke> close() {
    final p = Path()
      ..moveTo(7, 7)
      ..lineTo(17, 17)
      ..moveTo(17, 7)
      ..lineTo(7, 17);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Voltar**.
  static List<ClayStroke> back() {
    final p = Path()
      ..moveTo(14.6, 5.6)
      ..lineTo(8.2, 12)
      ..lineTo(14.6, 18.4);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Câmera indisponível** — corpo de câmera cortado.
  static List<ClayStroke> cameraOff() {
    final p = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.2, 7.2, 13.4, 9.6),
          const Radius.circular(3.2),
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: const Offset(9.9, 12),
          radius: 2.9,
        ),
      )
      ..moveTo(13.6, 7.2)
      ..lineTo(15, 5.8)
      ..lineTo(17.4, 5.8)
      ..lineTo(17.4, 7.2)
      ..moveTo(4.6, 19.4)
      ..lineTo(19.4, 4.6);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Confirmar**.
  static List<ClayStroke> check() {
    final p = Path()
      ..moveTo(5.2, 12.6)
      ..lineTo(9.6, 17)
      ..lineTo(18.8, 7.2);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Compartilhar / exportar**.
  static List<ClayStroke> share() {
    final p = Path()
      ..moveTo(12, 3.8)
      ..lineTo(12, 13.2)
      ..moveTo(8.9, 6.9)
      ..lineTo(12, 3.8)
      ..lineTo(15.1, 6.9)
      ..moveTo(5.6, 11.4)
      ..lineTo(5.6, 17.8)
      ..lineTo(18.4, 17.8)
      ..lineTo(18.4, 11.4);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Excluir** — massa sendo descartada.
  static List<ClayStroke> trash() {
    final p = Path()
      ..moveTo(4.8, 8)
      ..lineTo(19.2, 8)
      ..moveTo(9.6, 8)
      ..lineTo(9.6, 5.4)
      ..lineTo(14.4, 5.4)
      ..lineTo(14.4, 8)
      ..moveTo(6.8, 8)
      ..lineTo(7.9, 19.4)
      ..lineTo(16.1, 19.4)
      ..lineTo(17.2, 8);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Adicionar**.
  static List<ClayStroke> plus() {
    final p = Path()
      ..moveTo(12, 5.6)
      ..lineTo(12, 18.4)
      ..moveTo(5.6, 12)
      ..lineTo(18.4, 12);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// **Tentar de novo** — ciclo.
  static List<ClayStroke> retry() {
    return <ClayStroke>[
      _arcWithHead(const Offset(12, 12), 8.4, math.pi * 0.28, math.pi * 1.5)
    ];
  }

  /// **Mover / arrastar** — usado nas dicas de gesto.
  static List<ClayStroke> drag() {
    final p = Path()
      ..moveTo(12, 5.4)
      ..lineTo(12, 18.6)
      ..moveTo(8.4, 9)
      ..lineTo(12, 5.4)
      ..lineTo(15.6, 9)
      ..moveTo(8.4, 15)
      ..lineTo(12, 18.6)
      ..lineTo(15.6, 15);
    return <ClayStroke>[ClayStroke(p, width: 1.7)];
  }

  /// **Marca** — a gota de argila com a dobra. Assinatura do CLAY MORPHIST.
  static List<ClayStroke> mark() {
    final blob = Path()
      ..moveTo(12, 3.2)
      ..cubicTo(17.4, 3.2, 20.8, 7, 20.8, 12)
      ..cubicTo(20.8, 17.6, 16.5, 20.8, 11.4, 20.8)
      ..cubicTo(6.3, 20.8, 3.2, 17.5, 3.2, 12.4)
      ..cubicTo(3.2, 7, 7.4, 3.2, 12, 3.2)
      ..close();
    final crease = Path()
      ..moveTo(7.8, 10.1)
      ..cubicTo(10.6, 7.9, 14.6, 9.4, 15.8, 12.4);
    return <ClayStroke>[
      ClayStroke(blob, width: 1.7),
      ClayStroke(crease, width: 1.5)
    ];
  }

  /// **Velocidade do movimento** — `lines` marcas de deslocamento.
  /// Três marcas = movimento pleno; uma = reduzido. A leitura é literal: o
  /// próprio glifo desenha a quantidade de movimento que o app vai ter.
  static List<ClayStroke> speed({int lines = 3}) {
    final p = Path();
    const lengths = <double>[15.6, 11.4, 7.2];
    final count = lines.clamp(1, 3);
    for (var i = 0; i < count; i++) {
      final y = 7.6 + i * 4.4;
      p.moveTo(12 - lengths[i] / 2, y);
      p.lineTo(12 + lengths[i] / 2, y);
    }
    return <ClayStroke>[ClayStroke(p, width: 2.1)];
  }

  /// **Vibração** — oscilação.
  static List<ClayStroke> pulse() {
    final p = Path()
      ..moveTo(3.6, 12)
      ..lineTo(7.4, 7.4)
      ..lineTo(11, 16.6)
      ..lineTo(14.6, 7.4)
      ..lineTo(18.2, 12)
      ..lineTo(20.4, 12);
    return <ClayStroke>[ClayStroke(p)];
  }

  /// Arco com ponta de seta calculada na tangente.
  static ClayStroke _arcWithHead(
    Offset c,
    double r,
    double start,
    double sweep, {
    double head = 3.6,
  }) {
    final p = Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), start, sweep);
    final endAngle = start + sweep;
    final end =
        Offset(c.dx + r * math.cos(endAngle), c.dy + r * math.sin(endAngle));
    // Derivada de (cos, sin) em coordenadas de tela (y cresce para baixo).
    final tangent = math.atan2(math.cos(endAngle), -math.sin(endAngle));
    for (final side in <double>[-1, 1]) {
      final a = tangent + math.pi + side * 0.58;
      p.moveTo(end.dx, end.dy);
      p.lineTo(end.dx + head * math.cos(a), end.dy + head * math.sin(a));
    }
    return ClayStroke(p);
  }
}

/// Cache de glifos por chave.
///
/// `Path` é mutável e cada chamada de `ClayGlyphs.aperture()` devolve um
/// objeto novo — sem cache, o `CustomPainter` repintaria em todo frame porque
/// a identidade do caminho mudou. Aqui a identidade é estável por chave, e o
/// glifo só é redesenhado quando o estado que o define muda de verdade.
abstract final class ClayGlyphCache {
  static final Map<String, List<ClayStroke>> _cache =
      <String, List<ClayStroke>>{};

  static List<ClayStroke> of(String key, List<ClayStroke> Function() build) =>
      _cache.putIfAbsent(key, build);
}
