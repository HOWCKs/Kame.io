import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../motion/clay_motion.dart';
import '../navigation/clay_route.dart';
import '../services/clay_settings.dart';
import '../services/morph_vault.dart';
import '../theme/clay_tokens.dart';
import '../widgets/clay_field.dart';
import '../widgets/clay_states.dart';
import 'studio_screen.dart';

/// Primeira abertura.
///
/// Em vez de um carrossel de três frases, uma única decisão: o usuário vê a
/// matéria, entende que ela responde ao toque e concede a permissão no
/// momento em que isso faz sentido. Onboarding comprido é abandono; onboarding
/// com uma ação óbvia é conversão.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.settings,
    required this.vault,
  });

  final ClaySettings settings;
  final MorphVault vault;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _requesting = false;
  bool _blocked = false;

  Future<void> _begin() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) status = await Permission.camera.request();
      if (!mounted) return;

      if (status.isGranted || status.isLimited) {
        await widget.settings.completeOnboarding();
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          ClayPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            motion: ClayMotionScope.of(context),
            builder: (_) => StudioScreen(
              settings: widget.settings,
              vault: widget.vault,
            ),
          ),
        );
        return;
      }
      setState(() => _blocked = status.isPermanentlyDenied);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: ClayPalette.abyss,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ClaySpace.lg,
                ClaySpace.lg,
                ClaySpace.lg,
                bottom + ClaySpace.lg,
              ),
              child: Column(
                children: <Widget>[
                  // A massa é a explicação: quem nunca leu uma linha sobre o
                  // app já entendeu do que ele se trata depois de empurrá-la.
                  const Expanded(
                    child: ClayField(
                      hint: 'empurre a massa',
                      quality: 44,
                      semanticLabel: 'Massa de argila interativa',
                    ),
                  ),
                  const SizedBox(height: ClaySpace.lg),
                  Text(
                    'Toda foto começa macia.',
                    textAlign: TextAlign.center,
                    style: ClayType.display(),
                  ),
                  const SizedBox(height: ClaySpace.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      'Toque, segure, deforme. O Kame.io responde com peso — '
                      'cada captura vira uma forma guardada no seu Atlas.',
                      textAlign: TextAlign.center,
                      style: ClayType.body(color: ClayPalette.ash),
                    ),
                  ),
                  const SizedBox(height: ClaySpace.xl),
                  ClayActionPill(
                    label: _requesting ? 'Preparando…' : 'Dar forma',
                    onTap: _requesting ? () {} : _begin,
                    enabled: !_requesting,
                  ),
                  const SizedBox(height: ClaySpace.md),
                  AnimatedOpacity(
                    opacity: _blocked ? 1 : 0,
                    duration: ClayDurations.quick,
                    child: _blocked
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'A câmera está bloqueada para o Kame.io. '
                                'Libere em Ajustes do sistema → Aplicativos → '
                                'Kame.io → Permissões.',
                                textAlign: TextAlign.center,
                                style: ClayType.bodySm(
                                  color: ClayPalette.smoke,
                                ),
                              ),
                              const SizedBox(height: ClaySpace.sm),
                              ClayActionPill(
                                label: 'Abrir ajustes do sistema',
                                quiet: true,
                                onTap: openAppSettings,
                              ),
                            ],
                          )
                        : const SizedBox(height: 96),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
