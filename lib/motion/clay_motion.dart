import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Durações do sistema.
///
/// Escala curta: a interface nunca espera. Mesmo a transição mais longa
/// (“sculpt”, 620 ms) só aparece em trocas de tela, nunca em feedback de toque.
class ClayDurations {
  ClayDurations._();

  /// 90 ms — resposta ao toque (afundar da matéria).
  static const Duration flick = Duration(milliseconds: 90);

  /// 180 ms — troca de estado (cor, ícone, seleção).
  static const Duration quick = Duration(milliseconds: 180);

  /// 340 ms — mudança de forma e de layout.
  static const Duration morph = Duration(milliseconds: 340);

  /// 620 ms — entrada de tela / peça heroica.
  static const Duration sculpt = Duration(milliseconds: 620);

  /// 1600 ms — respiração da matéria (idle). Nunca é percebida como “animação”,
  /// é percebida como material vivo. Desligada em movimento reduzido.
  static const Duration breathe = Duration(milliseconds: 1600);
}

/// Curvas com peso.
///
/// [squish] é a assinatura do sistema: passa do alvo e volta, como argila
/// sendo solta. [melt] é usada quando a matéria se reorganiza (modo, navegação):
/// começa devagar, acelera, freia — nunca linear.
class ClayCurves {
  ClayCurves._();

  static const Curve softOut = Cubic(0.22, 1, 0.36, 1);
  static const Curve squish = Cubic(0.34, 1.42, 0.64, 1);
  static const Curve melt = Cubic(0.7, 0, 0.3, 1);
  static const Curve glide = Cubic(0.4, 0, 0.2, 1);
  static const Curve linear = Curves.linear;
}

/// Dados de movimento resolvidos para a árvore atual.
///
/// Quando o usuário pede movimento reduzido (sistema ou ajuste do app),
/// as durações colapsam para [ClayDurations.flick] e as curvas ficam lineares:
/// a interface continua funcionando e legível, só deixa de se mover.
class ClayMotionData {
  const ClayMotionData({
    required this.reduced,
    required this.flick,
    required this.quick,
    required this.morph,
    required this.sculpt,
    required this.haptics,
  });

  final bool reduced;
  final Duration flick;
  final Duration quick;
  final Duration morph;
  final Duration sculpt;

  /// Háptica é movimento que se sente: desliga junto.
  final bool haptics;

  Curve curve(Curve c) => reduced ? Curves.linear : c;

  /// Duração já ajustada: valores longos encolhem proporcionalmente em vez de
  /// sumir, para o estado intermediário continuar perceptível.
  Duration d(Duration base) {
    if (!reduced) return base;
    final ms = (base.inMilliseconds * 0.25).round();
    return Duration(milliseconds: ms < 60 ? 60 : ms);
  }
}

/// Escopo de movimento. Envolve o app inteiro (acima do `MaterialApp`) e
/// combina duas fontes de verdade:
///  1. `MediaQuery.disableAnimations` — preferência do sistema;
///  2. o ajuste do app em `ClaySettingsController` (pode forçar reduzido
///     mesmo que o sistema não peça).
class ClayMotionScope extends InheritedNotifier<ValueNotifier<ClayMotionConfig>> {
  const ClayMotionScope({
    super.key,
    required ValueNotifier<ClayMotionConfig> config,
    required super.child,
  }) : super(notifier: config);

  static ClayMotionData of(BuildContext context) {
    final notifier =
        context.dependOnInheritedWidgetOfExactType<ClayMotionScope>()?.notifier;
    final config = notifier?.value ?? const ClayMotionConfig();
    final systemReduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final reduced = config.motion == ClayMotionMode.reduced ||
        (config.motion == ClayMotionMode.system && systemReduced);

    return ClayMotionData(
      reduced: reduced,
      flick: reduced ? const Duration(milliseconds: 60) : ClayDurations.flick,
      quick: reduced ? const Duration(milliseconds: 70) : ClayDurations.quick,
      morph: reduced ? const Duration(milliseconds: 90) : ClayDurations.morph,
      sculpt: reduced ? const Duration(milliseconds: 120) : ClayDurations.sculpt,
      haptics: config.haptics && !reduced,
    );
  }
}

/// Preferência de movimento escolhida pelo usuário.
enum ClayMotionMode { system, full, reduced }

@immutable
class ClayMotionConfig {
  const ClayMotionConfig({
    this.motion = ClayMotionMode.system,
    this.haptics = true,
  });

  final ClayMotionMode motion;
  final bool haptics;

  ClayMotionConfig copyWith({ClayMotionMode? motion, bool? haptics}) =>
      ClayMotionConfig(
        motion: motion ?? this.motion,
        haptics: haptics ?? this.haptics,
      );

  @override
  bool operator ==(Object other) =>
      other is ClayMotionConfig &&
      other.motion == motion &&
      other.haptics == haptics;

  @override
  int get hashCode => Object.hash(motion, haptics);
}

/// Feedback tátil centralizado — e silencioso quando o movimento está reduzido.
class ClayHaptics {
  ClayHaptics._();

  static void tap(BuildContext context) {
    if (!ClayMotionScope.of(context).haptics) return;
    HapticFeedback.selectionClick();
  }

  static void shape(BuildContext context) {
    if (!ClayMotionScope.of(context).haptics) return;
    HapticFeedback.mediumImpact();
  }

  static void settle(BuildContext context) {
    if (!ClayMotionScope.of(context).haptics) return;
    HapticFeedback.lightImpact();
  }

  static void reject(BuildContext context) {
    if (!ClayMotionScope.of(context).haptics) return;
    HapticFeedback.heavyImpact();
  }
}
