import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/kame_theme.dart';
import '../widgets/clay.dart';
import '../widgets/clay_morph.dart';

/// Grade de fotos/vídeos capturados ou importados.
///
/// [initialItems] vem da tela de câmera (mídias capturadas); [onClose]
/// renderiza o botão de voltar quando exibida como overlay.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    this.initialItems = const [],
    this.onClose,
  });

  final List<XFile> initialItems;
  final VoidCallback? onClose;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final List<XFile> _items = List.of(widget.initialItems);
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  Future<void> _pick() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 100);
      if (!mounted) return;
      setState(() => _items.insertAll(0, picked));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a galeria: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KameTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KameTokens.gap,
                8,
                KameTokens.gap,
                8,
              ),
              child: Row(
                children: <Widget>[
                  if (widget.onClose != null) ...<Widget>[
                    ClayIconButton(
                      icon: Icons.arrow_back_rounded,
                      iconColor: ClayTokens.muted,
                      size: 40,
                      tooltip: 'Voltar para a câmera',
                      onTap: widget.onClose!,
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Text(
                    'Galeria',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  ClayPill(
                    child: Text(
                      '${_items.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  ClayButton(
                    label: 'Adicionar',
                    icon: Icons.add_photo_alternate_outlined,
                    color: _loading ? ClayTokens.nightRim : ClayTokens.clay,
                    onTap: _loading ? () {} : () => _pick(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const ClayMorph(size: 140, color: ClayTokens.violet),
                            const SizedBox(height: 24),
                            Text(
                              'Nenhuma foto ainda.\nToque no obturador na tela da câmera ou importe da galeria do aparelho.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: KameTokens.muted.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ClayButton(
                              label: 'Importar fotos',
                              icon: Icons.folder_open_rounded,
                              color: ClayTokens.violet,
                              onTap: _loading ? () {} : () => _pick(),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        KameTokens.gap,
                        0,
                        KameTokens.gap,
                        40,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final isVideo =
                            item.path.toLowerCase().endsWith('.mp4') ||
                                item.path.toLowerCase().endsWith('.mov');
                        return ClaySurface(
                          radius: ClayTokens.rSm,
                          depth: 5,
                          color: ClayTokens.nightSoft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(ClayTokens.rSm),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                if (isVideo)
                                  const ColoredBox(color: Color(0xFF20263E))
                                else
                                  Image.file(
                                    File(item.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        const ColoredBox(
                                      color: KameTokens.surface,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: KameTokens.muted,
                                      ),
                                    ),
                                  ),
                                if (isVideo)
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: KameTokens.primary,
                                      size: 34,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
