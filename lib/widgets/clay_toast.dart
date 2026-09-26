import 'package:flutter/material.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../theme/clay_tokens.dart';
import 'clay_glyph_view.dart';
import 'clay_surface.dart';

/// Um pedido de feedback. O `id` muda a cada chamada para que o mesmo texto
/// dispare a animação de novo.
@immutable
class ClayToastRequest {
  const ClayToastRequest({
    required this.id,
    required this.message,
    this.glyph,
    this.actionLabel,
    this.onAction,
  });

  final int id;
  final String message;
  final List<ClayStroke>? glyph;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Feedback com massa.
///
/// A laje sobe do fundo, passa do ponto e assenta — o mesmo comportamento da
/// argila em qualquer lugar do sistema. Tempo de permanência: 2,6 s, o
/// suficiente para ler uma frase curta sem atrasar o próximo disparo.
class ClayToastOverlay extends StatefulWidget {
  const ClayToastOverlay({super.key, required this.request});

  final ClayToastRequest? request;

  @override
  State<ClayToastOverlay> createState() => _ClayToastOverlayState();
}

class _ClayToastOverlayState extends State<ClayToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClayDurations.quick,
  );

  ClayToastRequest? _current;

  @override
  void didUpdateWidget(covariant ClayToastOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.request;
    if (next != null && next.id != _current?.id) {
      _current = next;
      _controller.forward(from: 0).then((_) => _hold());
    }
  }

  Future<void> _hold() async {
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (mounted) await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _current;
    final motion = ClayMotionScope.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        if (request == null || _controller.value == 0) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          ignoring: _controller.value < 0.9,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - t)),
            child: Opacity(
              opacity: t,
              child: _Slab(request: request, motion: motion),
            ),
          ),
        );
      },
    );
  }
}

class _Slab extends StatelessWidget {
  const _Slab({required this.request, required this.motion});

  final ClayToastRequest request;
  final ClayMotionData motion;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      kind: ClayMaterialKind.porcelain,
      pressable: false,
      radius: ClayRadii.chip + 4,
      elevation: ClayElevation.l2,
      padding: const EdgeInsets.symmetric(
        horizontal: ClaySpace.md,
        vertical: ClaySpace.sm + 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (request.glyph != null) ...<Widget>[
            ClayGlyphView(
              glyph: request.glyph!,
              size: 18,
              color: ClayPalette.kilnDark,
            ),
            const SizedBox(width: ClaySpace.sm),
          ],
          Flexible(
            child: Text(
              request.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ClayType.bodySm(color: ClayPalette.ink),
            ),
          ),
          if (request.actionLabel != null) ...<Widget>[
            const SizedBox(width: ClaySpace.sm),
            TextButton(
              onPressed: request.onAction,
              style: TextButton.styleFrom(
                foregroundColor: ClayPalette.kilnDark,
                textStyle: ClayType.label(color: ClayPalette.kilnDark),
                padding: const EdgeInsets.symmetric(horizontal: ClaySpace.sm),
                minimumSize: const Size(48, 40),
              ),
              child: Text(request.actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
