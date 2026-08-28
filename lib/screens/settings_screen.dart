import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';

/// Preferências do app. Valores em memória por enquanto — troque o
/// armazenamento por `shared_preferences` quando precisar persistir.
///
/// [embedded] = true quando renderizada dentro do sheet de configurações da
/// tela de câmera (sem padding extra de tela cheia).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _grid = true;
  bool _sound = false;
  bool _saveToGallery = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        KameTokens.gap,
        widget.embedded ? KameTokens.gap : 8,
        KameTokens.gap,
        widget.embedded ? KameTokens.gap : 120,
      ),
      children: [
        const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: KameTokens.gap),
        _GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                value: _grid,
                onChanged: (v) => setState(() => _grid = v),
                title: const Text('Grade 3x3'),
                subtitle: const Text('Mostrar guias de enquadramento'),
                secondary: const Icon(Icons.grid_on_rounded),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
                title: const Text('Som do obturador'),
                secondary: const Icon(Icons.volume_up_rounded),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _saveToGallery,
                onChanged: (v) => setState(() => _saveToGallery = v),
                title: const Text('Salvar na galeria'),
                subtitle: const Text('Copiar as fotos para o aparelho'),
                secondary: const Icon(Icons.save_alt_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: KameTokens.gap),
        _GlassCard(
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Kame.io'),
                subtitle: Text('Versão 1.0.0 (build 1)'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.build_rounded),
                title: Text('Build'),
                subtitle: Text('Gerado pelo GitHub Actions'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KameTokens.glassFill,
        borderRadius: BorderRadius.circular(KameTokens.radiusCard),
        border: Border.all(color: KameTokens.glassStroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
