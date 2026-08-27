import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';

class KameDestination {
  const KameDestination({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

/// Translucent bottom navigation bar.
///
/// Visual language: a floating "glass" pill (BackdropFilter blur + hairline
/// stroke + layered shadow) with a soft gradient tint sliding behind the
/// selected item while the other items stay quiet greys.
///
/// [GlassBottomNav] is a plain widget: it exposes the selected [index] and an
/// [onChanged] callback, so it can be dropped into any Scaffold.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onChanged,
    this.blur = 24,
  });

  final int index;
  final List<KameDestination> destinations;
  final ValueChanged<int> onChanged;
  final double blur;

  static const double _height = 68;
  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(_margin, 0, _margin, 12),
      child: SizedBox(
        height: _height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KameTokens.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: KameTokens.glassFill,
                borderRadius: BorderRadius.all(
                  Radius.circular(KameTokens.radiusPill),
                ),
                border: Border.fromBorderSide(
                  BorderSide(color: KameTokens.glassStroke),
                ),
                boxShadow: [
                  // depth
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                  // inner light, faked with a tight top offset
                  BoxShadow(
                    color: Color(0x14FFFFFF),
                    blurRadius: 1,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth / destinations.length;
                  return Stack(
                    children: [
                      _SlidingTint(
                        width: width,
                        index: index,
                        count: destinations.length,
                      ),
                      Row(
                        children: List.generate(destinations.length, (i) {
                          final destination = destinations[i];
                          final selected = i == index;
                          return Expanded(
                            child: _NavItem(
                              destination: destination,
                              selected: selected,
                              onTap: () => onChanged(i),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient halo that travels between slots.
class _SlidingTint extends StatelessWidget {
  const _SlidingTint({
    required this.width,
    required this.index,
    required this.count,
  });

  final double width;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final left = index * width;
    return AnimatedPositioned(
      duration: KameTokens.smooth,
      curve: KameTokens.spring,
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KameTokens.radiusPill),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KameTokens.primary.withValues(alpha: 0.26),
                KameTokens.secondary.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: KameTokens.primary.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: KameTokens.primary.withValues(alpha: 0.30),
                blurRadius: 22,
                spreadRadius: -6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final KameDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? KameTokens.onSurface : KameTokens.muted;
    final scale = selected ? 1.10 : 1.0;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KameTokens.radiusPill),
        splashColor: KameTokens.primary.withValues(alpha: 0.10),
        highlightColor: Colors.transparent,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: scale),
                duration: KameTokens.smooth,
                curve: KameTokens.spring,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Icon(
                  selected
                      ? destination.activeIcon ?? destination.icon
                      : destination.icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1,
                  letterSpacing: 0.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
                child: Text(destination.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
