import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../services/clay_settings.dart';
import '../services/morph_vault.dart';
import '../shape/clay_squircle.dart';
import '../theme/clay_tokens.dart';
import '../widgets/clay_controls.dart';
import '../widgets/clay_field.dart';
import '../widgets/clay_glyph_view.dart';
import '../widgets/clay_states.dart';
import '../widgets/clay_surface.dart';

/// O Atlas: biblioteca das formas capturadas.
///
/// Cada item é uma peça de matéria, não um “card de galeria”: a miniatura
/// guarda o mesmo raio contínuo do resto do sistema, a seleção **infla** a
/// peça e o estado escolhido aparece por volume + selo, nunca só por cor.
class AtlasScreen extends StatefulWidget {
  const AtlasScreen({
    super.key,
    required this.settings,
    required this.vault,
  });

  final ClaySettings settings;
  final MorphVault vault;

  @override
  State<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends State<AtlasScreen> {
  final Set<String> _selected = <String>{};
  bool _selecting = false;
  bool _busy = false;

  bool get _hasSelection => _selected.isNotEmpty;

  int _columnsFor(double width) {
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 600) return 4;
    return 3;
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  void _enterSelection(String path) {
    ClayHaptics.shape(context);
    setState(() {
      _selecting = true;
      _selected.add(path);
    });
  }

  void _exitSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 100);
      if (!mounted) return;
      for (final file in picked) {
        await widget.vault.add(file, persist: widget.settings.persist);
      }
    } catch (e) {
      if (!mounted) return;
      _feedback('Não foi possível importar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _feedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ClayPalette.clayMid,
        ),
      );
  }

  Future<void> _share(List<MorphItem> items) async {
    if (items.isEmpty) return;
    try {
      await Share.shareXFiles(
        items.map((item) => XFile(item.path)).toList(growable: false),
        text: 'Formas feitas no Kame.io',
      );
    } catch (e) {
      if (!mounted) return;
      _feedback('Não foi possível compartilhar: $e');
    }
  }

  Future<void> _confirmDelete(List<MorphItem> items) async {
    if (items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ClayConfirmDialog(
        title: items.length == 1 ? 'Excluir esta forma?' : 'Excluir ${items.length} formas?',
        message:
            'As peças saem do Atlas e do aparelho. Não dá para desfazer depois.',
        confirmLabel: 'Excluir',
        cancelLabel: 'Cancelar',
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final item in items) {
      await widget.vault.remove(item);
    }
    setState(() => _selected.clear());
    if (items.length > 1) _exitSelection();
  }

  void _openDetail(MorphItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MorphSheet(
        item: item,
        onShare: () => _share(<MorphItem>[item]),
        onDelete: () {
          Navigator.of(context).pop();
          _confirmDelete(<MorphItem>[item]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayPalette.abyss,
      body: SafeArea(
        // O Atlas é uma visão viva do cofre: qualquer mudança no acervo
        // (importar, excluir, promover) redesenha a grade aqui.
        child: ListenableBuilder(
          listenable: widget.vault,
          builder: (context, _) {
            final items = widget.vault.items;
            final columns = _columnsFor(MediaQuery.sizeOf(context).width);
            return Column(
              children: <Widget>[
                _buildHeader(items.length),
                Expanded(child: _buildBody(items, columns)),
                if (_selecting) _buildSelectionBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClaySpace.md,
        ClaySpace.sm,
        ClaySpace.md,
        ClaySpace.sm,
      ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Atlas', style: ClayType.title()),
              Text(
                count == 0
                    ? 'nenhuma forma ainda'
                    : count == 1
                        ? '1 forma guardada'
                        : '$count formas guardadas',
                style: ClayType.micro(color: ClayPalette.smoke),
              ),
            ],
          ),
          const Spacer(),
          if (!_selecting) ...<Widget>[
            ClayIconButton(
              kind: ClayMaterialKind.obsidian,
              width: 48,
              height: 48,
              showLabel: false,
              label: 'Importar do aparelho',
              glyph: ClayGlyphs.plus(),
              enabled: !_busy,
              onTap: _import,
              tooltip: 'Importar fotos do aparelho',
            ),
            const SizedBox(width: ClaySpace.xs),
            ClayIconButton(
              kind: ClayMaterialKind.obsidian,
              width: 48,
              height: 48,
              showLabel: false,
              label: 'Selecionar',
              glyph: ClayGlyphs.check(),
              enabled: widget.vault.items.isNotEmpty,
              onTap: () => setState(() => _selecting = true),
              tooltip: 'Selecionar formas',
            ),
          ] else ...<Widget>[
            TextButton(
              onPressed: _exitSelection,
              style: TextButton.styleFrom(
                foregroundColor: ClayPalette.chalk,
                minimumSize: const Size(64, 48),
              ),
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(List<MorphItem> items, int columns) {
    if (widget.vault.loading) {
      return const ClayBooting(message: 'Reunindo as formas…');
    }
    if (widget.vault.error != null) {
      return ClayErrorState(
        title: 'O Atlas não abriu',
        message: widget.vault.error!,
        actionLabel: 'Tentar de novo',
        onAction: () => widget.vault.load(widget.settings),
      );
    }
    if (items.isEmpty) {
      return ClayEmptyState(
        title: 'Ainda não há nada moldado',
        message:
            'Cada captura vira uma peça aqui. Toque no obturador no Estúdio e a primeira forma aparece nesta prateleira.',
        hero: SizedBox(
          height: 190,
          child: ClayField(
            hint: 'arraste a massa',
            quality: 40,
          ),
        ),
        actionLabel: 'Ir para o Estúdio',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        ClaySpace.md,
        ClaySpace.sm,
        ClaySpace.md,
        ClaySpace.xl,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: ClaySpace.sm + 2,
        crossAxisSpacing: ClaySpace.sm + 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = _selected.contains(item.path);
        return _MorphTile(
          item: item,
          selected: selected,
          onTap: () {
            if (_selecting) {
              _toggleSelection(item.path);
            } else {
              _openDetail(item);
            }
          },
          onLongPress: () => _enterSelection(item.path),
        );
      },
    );
  }

  Widget _buildSelectionBar() {
    final selected = widget.vault.items
        .where((item) => _selected.contains(item.path))
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClaySpace.md,
        ClaySpace.sm,
        ClaySpace.md,
        ClaySpace.md,
      ),
      decoration: const BoxDecoration(
        color: ClayPalette.bedrock,
        border: Border(top: BorderSide(color: ClayPalette.rim)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Text(
              '${_selected.length} selecionada${_selected.length == 1 ? '' : 's'}',
              style: ClayType.label(color: ClayPalette.ash),
            ),
            const Spacer(),
            ClayActionPill(
              label: 'Compartilhar',
              glyph: ClayGlyphs.share(),
              enabled: _hasSelection,
              onTap: () => _share(selected),
              quiet: !_hasSelection,
            ),
            const SizedBox(width: ClaySpace.sm),
            ClayActionPill(
              label: 'Excluir',
              glyph: ClayGlyphs.trash(),
              quiet: true,
              enabled: _hasSelection,
              onTap: () => _confirmDelete(selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// Peça do Atlas.
class _MorphTile extends StatelessWidget {
  const _MorphTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final MorphItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      kind: ClayMaterialKind.obsidian,
      radius: ClayRadii.card,
      padding: EdgeInsets.zero,
      elevation: selected ? ClayElevation.l2 : ClayElevation.l1,
      tint: selected ? ClayPalette.kiln : null,
      glow: selected ? ClayPalette.kiln : null,
      semanticLabel: item.video ? 'Vídeo capturado' : 'Foto capturada',
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipPath(
            clipper: _TileClipper(ClayRadii.card - 3),
            child: item.video
                ? Container(
                    color: ClayPalette.clayMid,
                    alignment: Alignment.center,
                    child: ClayGlyphView(
                      glyph: ClayGlyphs.reel(),
                      size: 26,
                      color: ClayPalette.chalk,
                    ),
                  )
                : Image.file(
                    File(item.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: ClayPalette.clayMid,
                      alignment: Alignment.center,
                      child: ClayGlyphView(
                        glyph: ClayGlyphs.cameraOff(),
                        size: 24,
                        color: ClayPalette.smoke,
                      ),
                    ),
                  ),
          ),
          if (selected)
            Positioned(
              right: 6,
              top: 6,
              child: ClaySurface(
                pressable: false,
                kind: ClayMaterialKind.glaze,
                radius: ClayRadii.pill,
                padding: const EdgeInsets.all(4),
                child: ClayGlyphView(
                  glyph: ClayGlyphs.check(),
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TileClipper extends CustomClipper<Path> {
  _TileClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => ClayShape.squircle(Offset.zero & size, radius);

  @override
  bool shouldReclip(covariant _TileClipper oldClipper) =>
      oldClipper.radius != radius;
}

/// Ficha da forma: metadados reais + ações que existem.
class _MorphSheet extends StatelessWidget {
  const _MorphSheet({
    required this.item,
    required this.onShare,
    required this.onDelete,
  });

  final MorphItem item;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final created =
        '${item.created.day.toString().padLeft(2, '0')}/${item.created.month.toString().padLeft(2, '0')} · ${item.created.hour.toString().padLeft(2, '0')}:${item.created.minute.toString().padLeft(2, '0')}';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: ClaySpace.sm),
          // Alça: a mesma massa dos controles.
          ClaySurface(
            pressable: false,
            width: 46,
            height: 6,
            radius: 3,
            padding: EdgeInsets.zero,
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: ClaySpace.sm),
          Flexible(
            child: ClaySurface(
              pressable: false,
              kind: ClayMaterialKind.obsidian,
              radius: ClayRadii.sheet,
              elevation: ClayElevation.l2,
              padding: const EdgeInsets.all(ClaySpace.lg),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  ClipPath(
                    clipper: _TileClipper(ClayRadii.card),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: item.video
                          ? Container(
                              color: ClayPalette.clayMid,
                              alignment: Alignment.center,
                              child: ClayGlyphView(
                                glyph: ClayGlyphs.reel(),
                                size: 48,
                                color: ClayPalette.chalk,
                              ),
                            )
                          : Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: ClayPalette.clayMid,
                                alignment: Alignment.center,
                                child: ClayGlyphView(
                                  glyph: ClayGlyphs.cameraOff(),
                                  size: 40,
                                  color: ClayPalette.smoke,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: ClaySpace.lg),
                  Text('Forma', style: ClayType.section()),
                  const SizedBox(height: ClaySpace.sm),
                  _MetaRow(
                    label: 'Tipo',
                    value: item.video ? 'Vídeo' : 'Foto',
                  ),
                  _MetaRow(label: 'Criada', value: created),
                  _MetaRow(label: 'Tamanho', value: item.sizeLabel),
                  const SizedBox(height: ClaySpace.lg),
                  Wrap(
                    spacing: ClaySpace.sm,
                    children: <Widget>[
                      ClayActionPill(
                        label: 'Compartilhar',
                        glyph: ClayGlyphs.share(),
                        onTap: onShare,
                      ),
                      ClayActionPill(
                        label: 'Excluir',
                        glyph: ClayGlyphs.trash(),
                        quiet: true,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                  const SizedBox(height: ClaySpace.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClaySpace.xs + 2),
      child: Row(
        children: <Widget>[
          Text(label, style: ClayType.bodySm(color: ClayPalette.smoke)),
          const Spacer(),
          Text(value, style: ClayType.label(color: ClayPalette.chalk)),
        ],
      ),
    );
  }
}
