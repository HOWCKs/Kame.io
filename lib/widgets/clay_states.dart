import 'package:flutter/material.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../theme/clay_tokens.dart';
import 'clay_field.dart';
import 'clay_glyph_view.dart';
import 'clay_surface.dart';

/// Estado de carregamento do boot.
///
/// Não existe spinner genérico no CLAY MORPHIST: enquanto a câmera aquece,
/// a matéria se move. Se o usuário pediu movimento reduzido, a massa fica
/// parada e uma barra de progresso fina assume o papel de indicar trabalho.
class ClayBooting extends StatelessWidget {
  const ClayBooting({super.key, this.message = 'Aquecendo a matéria…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 132,
              child: ClayField(
                drift: true,
                interactive: false,
                quality: 36,
                semanticLabel: null,
              ),
            ),
            const SizedBox(height: ClaySpace.lg),
            Text(message, style: ClayType.body(color: ClayPalette.ash)),
            const SizedBox(height: ClaySpace.md),
            const SizedBox(
              width: 132,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: ClayPalette.clayMid,
                valueColor: AlwaysStoppedAnimation<Color>(ClayPalette.kiln),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio: criativo e útil.
///
/// Todo vazio no app tem (1) um objeto para tocar, (2) uma frase que explica
/// o que está faltando e (3) a ação que resolve. Nunca só um ícone triste.
class ClayEmptyState extends StatelessWidget {
  const ClayEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.glyph,
    this.actionLabel,
    this.onAction,
    this.hero,
  });

  final String title;
  final String message;
  final List<ClayStroke>? glyph;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? hero;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ClaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hero != null) hero!,
            if (glyph != null) ...<Widget>[
              ClayGlyphView(glyph: glyph!, size: 40, color: ClayPalette.smoke),
              const SizedBox(height: ClaySpace.md),
            ],
            if (hero != null) const SizedBox(height: ClaySpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ClayType.section(color: ClayPalette.chalk),
            ),
            const SizedBox(height: ClaySpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: ClayType.bodySm(color: ClayPalette.ash),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: ClaySpace.lg),
              ClayActionPill(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de erro: nome do problema, causa em linguagem humana e saída.
class ClayErrorState extends StatelessWidget {
  const ClayErrorState({
    super.key,
    required this.title,
    required this.message,
    this.glyph,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final List<ClayStroke>? glyph;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ClaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClayGlyphView(
              glyph: glyph ?? ClayGlyphs.cameraOff(),
              size: 44,
              color: ClayPalette.ember,
            ),
            const SizedBox(height: ClaySpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ClayType.section(color: ClayPalette.chalk),
            ),
            const SizedBox(height: ClaySpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: ClayType.bodySm(color: ClayPalette.ash),
              ),
            ),
            const SizedBox(height: ClaySpace.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: ClaySpace.sm,
              children: <Widget>[
                if (actionLabel != null && onAction != null)
                  ClayActionPill(label: actionLabel!, onTap: onAction!),
                if (secondaryLabel != null && onSecondary != null)
                  ClayActionPill(
                    label: secondaryLabel!,
                    onTap: onSecondary!,
                    quiet: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão de ação usado nos estados: massa de esmalte, área de toque generosa.
class ClayActionPill extends StatelessWidget {
  const ClayActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.glyph,
    this.quiet = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final List<ClayStroke>? glyph;
  final bool quiet;

  /// Desabilitado é melhor que escondido: o usuário vê que a ação existe e
  /// entende o que falta para liberá-la.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      kind: quiet ? ClayMaterialKind.obsidian : ClayMaterialKind.glaze,
      radius: ClayRadii.pill,
      elevation: quiet ? ClayElevation.flat : ClayElevation.l2,
      padding: const EdgeInsets.symmetric(
        horizontal: ClaySpace.lg,
        vertical: ClaySpace.sm + 2,
      ),
      enabled: enabled,
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            ClayGlyphView(
              glyph: glyph!,
              size: 18,
              color: quiet ? ClayPalette.chalk : Colors.white,
            ),
            const SizedBox(width: ClaySpace.sm),
          ],
          Text(
            label,
            style: ClayType.label(
              color: quiet ? ClayPalette.chalk : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Anel de foco: onde o dedo tocou, a massa responde.
class ClayFocusRing extends StatefulWidget {
  const ClayFocusRing({super.key, required this.position});

  final Offset position;

  @override
  State<ClayFocusRing> createState() => _ClayFocusRingState();
}

class _ClayFocusRingState extends State<ClayFocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 620));
      if (mounted) await _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = motion.reduced ? 1.0 : Curves.easeOutCubic.transform(_controller.value);
        final scale = 1.35 - 0.35 * t;
        return Positioned(
          left: widget.position.dx - 30,
          top: widget.position.dy - 30,
          child: IgnorePointer(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: t,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ClayPalette.porcelainEdge.withOpacity(0.85),
                      width: 2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ClayPalette.kiln.withOpacity(0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Confirmação de ação destrutiva: sempre com consequência escrita.
class ClayConfirmDialog extends StatelessWidget {
  const ClayConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(ClaySpace.lg),
      child: ClaySurface(
        pressable: false,
        kind: ClayMaterialKind.obsidian,
        radius: ClayRadii.sheet,
        elevation: ClayElevation.l3,
        padding: const EdgeInsets.all(ClaySpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClayGlyphView(
              glyph: ClayGlyphs.trash(),
              size: 30,
              color: ClayPalette.ember,
            ),
            const SizedBox(height: ClaySpace.md),
            Text(title, style: ClayType.section()),
            const SizedBox(height: ClaySpace.sm),
            Text(message, style: ClayType.bodySm(color: ClayPalette.ash)),
            const SizedBox(height: ClaySpace.lg),
            Wrap(
              spacing: ClaySpace.sm,
              children: <Widget>[
                ClayActionPill(
                  label: confirmLabel,
                  glyph: ClayGlyphs.trash(),
                  onTap: () => Navigator.of(context).pop(true),
                ),
                ClayActionPill(
                  label: cancelLabel,
                  quiet: true,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
