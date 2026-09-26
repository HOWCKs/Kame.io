import 'package:flutter/material.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../services/clay_settings.dart';
import '../services/morph_vault.dart';
import '../theme/clay_tokens.dart';
import '../widgets/clay_controls.dart';
import '../widgets/clay_field.dart';
import '../widgets/clay_glyph_view.dart';
import '../widgets/clay_states.dart';
import '../widgets/clay_surface.dart';

/// Ajustes.
///
/// Regra do sistema: **nenhum controle existe sem efeito**. Cada interruptor
/// aqui muda um comportamento verificável do app — inclusive o de movimento,
/// que desliga a própria animação desta tela.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.vault,
  });

  final ClaySettings settings;
  final MorphVault vault;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayPalette.abyss,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ClaySpace.md,
                    ClaySpace.sm,
                    ClaySpace.md,
                    ClaySpace.xxl,
                  ),
                  children: <Widget>[
                    _buildTitle(context),
                    const SizedBox(height: ClaySpace.lg),
                    _section(
                      'Matéria',
                      <Widget>[
                        _Row(
                          glyph: ClayGlyphs.dial(),
                          title: 'Movimento',
                          subtitle: 'Quanto a interface se move',
                          control: SizedBox(
                            width: 232,
                            child: ClayVein(
                              height: 52,
                              selected: settings.motion.index,
                              semanticLabel: 'Intensidade do movimento',
                              onChanged: (index) => settings.set(
                                'motion',
                                ClayMotionMode.values[index],
                              ),
                              segments: <ClaySegment>[
                                ClaySegment(
                                  label: 'Sistema',
                                  glyph: ClayGlyphs.dial(),
                                ),
                                ClaySegment(
                                  label: 'Completo',
                                  glyph: ClayGlyphs.speed(lines: 3),
                                ),
                                ClaySegment(
                                  label: 'Reduzido',
                                  glyph: ClayGlyphs.speed(lines: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _Divider(),
                        _Row(
                          glyph: ClayGlyphs.pulse(),
                          title: 'Vibração',
                          subtitle: 'Resposta tátil ao toque',
                          control: ClaySwitch(
                            value: settings.haptics,
                            semanticLabel: 'Vibração',
                            onChanged: (value) =>
                                settings.set('haptics', value),
                          ),
                        ),
                        _Divider(),
                        _Row(
                          glyph: ClayGlyphs.wave(),
                          title: 'Som do obturador',
                          subtitle: 'Clique ao capturar',
                          control: ClaySwitch(
                            value: settings.shutterSound,
                            semanticLabel: 'Som do obturador',
                            onChanged: (value) =>
                                settings.set('shutterSound', value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClaySpace.lg),
                    _section(
                      'Captura',
                      <Widget>[
                        _Row(
                          glyph: ClayGlyphs.grid(),
                          title: 'Grade 3×3',
                          subtitle: 'Guias de enquadramento no visor',
                          control: ClaySwitch(
                            value: settings.grid,
                            semanticLabel: 'Grade 3 por 3',
                            onChanged: (value) => settings.set('grid', value),
                          ),
                        ),
                        _Divider(),
                        _Row(
                          glyph: ClayGlyphs.tray(),
                          title: 'Manter as formas',
                          subtitle: settings.persist
                              ? 'As capturas ficam no aparelho depois de fechar'
                              : 'As capturas valem só para esta sessão',
                          control: ClaySwitch(
                            value: settings.persist,
                            semanticLabel: 'Manter as formas',
                            onChanged: (value) async {
                              settings.set('persist', value);
                              if (value) await vault.promoteAll();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClaySpace.lg),
                    _buildLab(),
                    const SizedBox(height: ClaySpace.lg),
                    _section(
                      'Sobre',
                      <Widget>[
                        _Row(
                          glyph: ClayGlyphs.mark(),
                          title: 'Kame.io',
                          subtitle: 'Versão 1.0.0 (build 2)',
                        ),
                        _Divider(),
                        const _Row(
                          glyph: null,
                          title: 'Design system',
                          subtitle: 'CLAY MORPHIST — matéria, luz e movimento',
                        ),
                      ],
                    ),
                    if (vault.items.isNotEmpty) ...<Widget>[
                      const SizedBox(height: ClaySpace.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ClaySpace.xs,
                        ),
                        child: ClayActionPill(
                          label: 'Esvaziar o Atlas',
                          glyph: ClayGlyphs.trash(),
                          quiet: true,
                          onTap: () => _confirmClear(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ClaySpace.xs),
      child: Row(
        children: <Widget>[
          ClayIconButton(
            kind: ClayMaterialKind.obsidian,
            width: 48,
            height: 48,
            showLabel: false,
            label: 'Voltar',
            glyph: ClayGlyphs.back(),
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: ClaySpace.sm),
          Text('Ajustes', style: ClayType.title()),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClaySpace.md,
            0,
            ClaySpace.md,
            ClaySpace.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: ClayType.micro(color: ClayPalette.smoke),
          ),
        ),
        ClaySurface(
          pressable: false,
          kind: ClayMaterialKind.obsidian,
          radius: ClayRadii.card,
          elevation: ClayElevation.l1,
          padding: const EdgeInsets.symmetric(
            horizontal: ClaySpace.sm,
            vertical: ClaySpace.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );
  }

  /// Laboratório: a matéria em estado puro, para o usuário entender o que o
  /// ajuste de movimento faz antes de decidir.
  Widget _buildLab() {
    return ClaySurface(
      pressable: false,
      kind: ClayMaterialKind.obsidian,
      radius: ClayRadii.card,
      elevation: ClayElevation.l1,
      padding: const EdgeInsets.all(ClaySpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            height: 168,
            child: ClayField(
              hint: 'arraste a massa',
              quality: 40,
              semanticLabel: 'Laboratório de matéria',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClaySpace.sm,
              ClaySpace.xs,
              ClaySpace.sm,
              ClaySpace.sm,
            ),
            child: Text(
              'A massa responde ao dedo e à luz. Em “Reduzido” ela para de '
              'respirar, mas continua deformando quando você a toca — quem '
              'move é você, não o sistema.',
              style: ClayType.bodySm(color: ClayPalette.ash),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ClayConfirmDialog(
        title: 'Esvaziar o Atlas?',
        message:
            'Todas as ${vault.items.length} formas serão apagadas do aparelho. Não dá para desfazer.',
        confirmLabel: 'Esvaziar',
        cancelLabel: 'Cancelar',
      ),
    );
    if (confirmed == true) await vault.clear();
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.glyph,
    this.control,
  });

  final String title;
  final String? subtitle;
  final List<ClayStroke>? glyph;
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ClaySpace.sm,
        vertical: ClaySpace.sm,
      ),
      child: Row(
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            ClayGlyphView(glyph: glyph!, size: 22, color: ClayPalette.kiln),
            const SizedBox(width: ClaySpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: ClayType.bodySm(color: ClayPalette.chalk)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: ClayType.micro(color: ClayPalette.smoke),
                  ),
                ],
              ],
            ),
          ),
          if (control != null) ...<Widget>[
            const SizedBox(width: ClaySpace.sm),
            control!,
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: ClaySpace.sm, endIndent: ClaySpace.sm);
  }
}
