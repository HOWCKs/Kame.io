import 'package:flutter/material.dart';

import 'motion/clay_motion.dart';
import 'navigation/clay_route.dart';
import 'screens/atlas_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'services/clay_settings.dart';
import 'services/morph_vault.dart';
import 'theme/clay_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await ClaySettings.load();
  final vault = MorphVault();
  await vault.load(settings);
  runApp(KameApp(settings: settings, vault: vault));
}

class KameApp extends StatefulWidget {
  const KameApp({
    super.key,
    required this.settings,
    required this.vault,
  });

  final ClaySettings settings;
  final MorphVault vault;

  @override
  State<KameApp> createState() => _KameAppState();
}

class _KameAppState extends State<KameApp> {
  late ValueNotifier<ClayMotionConfig> _motion;

  @override
  void initState() {
    super.initState();
    _motion = ValueNotifier<ClayMotionConfig>(widget.settings.motionConfig);
    widget.settings.addListener(_syncMotion);
  }

  void _syncMotion() {
    _motion.value = widget.settings.motionConfig;
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncMotion);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClayMotionScope(
      config: _motion,
      child: MaterialApp(
        title: 'Kame.io',
        debugShowCheckedModeBanner: false,
        theme: ClayTheme.dark(),
        builder: (context, child) {
          // O layout foi desenhado para escalar de 0,85× a 1,6×. Acima disso
          // a barra de controle quebraria; abaixo, os rótulos ficariam
          // ilegíveis. Limitar é preferível a quebrar.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.6,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        onGenerateRoute: (route) {
          final motion = ClayMotionScope.of(context);
          switch (route.name) {
            case '/atlas':
              return ClayPageRoute<void>(
                settings: route,
                motion: motion,
                builder: (_) => AtlasScreen(
                  settings: widget.settings,
                  vault: widget.vault,
                ),
              );
            case '/settings':
              return ClayPageRoute<void>(
                settings: route,
                motion: motion,
                builder: (_) => SettingsScreen(
                  settings: widget.settings,
                  vault: widget.vault,
                ),
              );
            case '/':
            default:
              return ClayPageRoute<void>(
                settings: route,
                motion: motion,
                builder: (_) => widget.settings.onboarded
                    ? StudioScreen(
                        settings: widget.settings, vault: widget.vault)
                    : OnboardingScreen(
                        settings: widget.settings,
                        vault: widget.vault,
                      ),
              );
          }
        },
      ),
    );
  }
}
