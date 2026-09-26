import 'package:flutter/material.dart';

import '../motion/clay_motion.dart';

/// Transição entre telas: a nova superfície **sobe e assenta**, a anterior
/// recua levemente — as duas se movem juntas, então a troca parece uma peça
/// de matéria substituindo a outra, e não um corte.
class ClayPageRoute<T> extends PageRouteBuilder<T> {
  ClayPageRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
    required ClayMotionData motion,
  }) : super(
          settings: settings,
          transitionDuration: motion.d(const Duration(milliseconds: 420)),
          reverseTransitionDuration:
              motion.d(const Duration(milliseconds: 320)),
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: motion.curve(const Cubic(0.22, 1, 0.36, 1)),
              reverseCurve: motion.curve(const Cubic(0.4, 0, 0.6, 1)),
            );
            final back = CurvedAnimation(
              parent: secondary,
              curve: motion.curve(const Cubic(0.4, 0, 0.6, 1)),
            );
            if (motion.reduced) {
              return FadeTransition(opacity: curved, child: child);
            }
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(0, -0.02),
                  ).animate(back),
                  child: child,
                ),
              ),
            );
          },
        );
}
