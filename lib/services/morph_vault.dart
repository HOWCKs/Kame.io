import 'dart:io';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'clay_settings.dart';

/// Uma forma capturada: foto ou vídeo guardado pelo Kame.io.
@immutable
class MorphItem {
  const MorphItem({
    required this.path,
    required this.created,
    required this.video,
    required this.bytes,
  });

  final String path;
  final DateTime created;
  final bool video;
  final int bytes;

  String get name {
    final parts = path.split('/');
    return parts.isEmpty ? path : parts.last;
  }

  String get sizeLabel {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  MorphItem copyWith({int? bytes}) => MorphItem(
        path: path,
        created: created,
        video: video,
        bytes: bytes ?? this.bytes,
      );
}

/// A biblioteca de formas (o “Atlas”).
///
/// Duas políticas de guarda, explícitas e reversíveis:
///  * **persist = true** — cada captura é copiada para o diretório de
///    documentos e sobrevive ao fechamento do app;
///  * **persist = false** — a captura fica no cache e existe só nesta sessão
///    (útil para quem não quer encher o aparelho).
class MorphVault extends ChangeNotifier {
  final List<MorphItem> _items = <MorphItem>[];

  List<MorphItem> get items => List<MorphItem>.unmodifiable(_items);

  bool loading = true;
  String? error;

  static const String _folder = 'kame_morphs';

  Future<Directory> _vaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> load(ClaySettings settings) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _items.clear();
      if (settings.persist) {
        final dir = await _vaultDir();
        final entities = dir.listSync().whereType<File>().toList()
          ..sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        for (final file in entities) {
          if (_isMedia(file.path)) {
            _items.add(
              MorphItem(
                path: file.path,
                created: file.lastModifiedSync(),
                video: isVideo(file.path),
                bytes: file.lengthSync(),
              ),
            );
          }
        }
      }
      loading = false;
    } catch (e) {
      loading = false;
      error = 'Não foi possível ler a biblioteca: $e';
    }
    notifyListeners();
  }

  /// Guarda uma captura. Devolve o item criado (ou `null` se falhou).
  Future<MorphItem?> add(XFile file, {required bool persist}) async {
    try {
      final video = isVideo(file.path);
      String finalPath = file.path;
      if (persist) {
        final dir = await _vaultDir();
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final ext = video ? '.mp4' : '.jpg';
        finalPath = '${dir.path}/kame_$stamp$ext';
        await File(file.path).copy(finalPath);
      }
      final saved = File(finalPath);
      final item = MorphItem(
        path: finalPath,
        created: DateTime.now(),
        video: video,
        bytes: await saved.exists() ? await saved.length() : 0,
      );
      _items.insert(0, item);
      notifyListeners();
      return item;
    } catch (e) {
      error = 'Não foi possível guardar a captura: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> remove(MorphItem item) async {
    try {
      final file = File(item.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Se o arquivo já não existe, remover da lista é o que importa.
    }
    _items.removeWhere((element) => element.path == item.path);
    notifyListeners();
  }

  Future<void> clear() async {
    for (final item in List<MorphItem>.of(_items)) {
      await remove(item);
    }
  }

  /// Migra as capturas da sessão para o diretório persistente quando o
  /// usuário liga “manter as formas”.
  Future<void> promoteAll() async {
    final dir = await _vaultDir();
    final promoted = <MorphItem>[];
    for (final item in _items) {
      if (item.path.startsWith(dir.path)) {
        promoted.add(item);
        continue;
      }
      try {
        final stamp = item.created.millisecondsSinceEpoch;
        final ext = item.video ? '.mp4' : '.jpg';
        final target = '${dir.path}/kame_$stamp$ext';
        await File(item.path).copy(target);
        promoted.add(
          MorphItem(
            path: target,
            created: item.created,
            video: item.video,
            bytes: await File(target).length(),
          ),
        );
      } catch (_) {
        promoted.add(item);
      }
    }
    _items
      ..clear()
      ..addAll(promoted);
    notifyListeners();
  }

  static bool isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov');
  }

  static bool _isMedia(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        isVideo(lower);
  }
}
