import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/kame_theme.dart';

/// Grid of photos captured / picked by the user.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<XFile> _items = [];
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
    return SafeArea(
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
              children: [
                const Text(
                  'Galeria',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_items.length}',
                  style: const TextStyle(color: KameTokens.muted, fontSize: 12),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Adicionar'),
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
                        children: [
                          const Icon(
                            Icons.collections_outlined,
                            size: 48,
                            color: KameTokens.muted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma foto ainda.\nTire uma na aba Câmera ou importe da galeria do aparelho.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: KameTokens.muted.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.tonalIcon(
                            onPressed: _loading ? null : _pick,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Importar fotos'),
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
                      120,
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
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(KameTokens.radiusCard / 2),
                        child: Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => ColoredBox(
                            color: KameTokens.surface,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: KameTokens.muted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
