import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../motion/clay_motion.dart';

/// Ajustes do Kame.io.
///
/// Persistidos como JSON no diretório de documentos do app. Não há chaves
/// mágicas: cada campo aqui controla um comportamento real e verificável —
/// nenhum interruptor existe só para ocupar espaço na tela.
class ClaySettings extends ChangeNotifier {
  ClaySettings({
    this.onboarded = false,
    this.grid = true,
    this.shutterSound = false,
    this.haptics = true,
    this.persist = true,
    this.motion = ClayMotionMode.system,
  });

  bool onboarded;
  bool grid;
  bool shutterSound;
  bool haptics;
  bool persist;
  ClayMotionMode motion;

  ClayMotionConfig get motionConfig =>
      ClayMotionConfig(motion: motion, haptics: haptics);

  static const String _fileName = 'kame_settings.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<ClaySettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return ClaySettings();
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ClaySettings(
        onboarded: map['onboarded'] as bool? ?? false,
        grid: map['grid'] as bool? ?? true,
        shutterSound: map['shutterSound'] as bool? ?? false,
        haptics: map['haptics'] as bool? ?? true,
        persist: map['persist'] as bool? ?? true,
        motion: ClayMotionMode.values.asNameMap()[(map['motion'] as String?)] ??
            ClayMotionMode.system,
      );
    } catch (_) {
      // Configuração corrompida ou sem permissão: começa limpo, não quebra.
      return ClaySettings();
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'onboarded': onboarded,
          'grid': grid,
          'shutterSound': shutterSound,
          'haptics': haptics,
          'persist': persist,
          'motion': motion.name,
        }),
      );
    } catch (_) {
      // Falha silenciosa de propósito: perder uma preferência não pode
      // derrubar a câmera.
    }
  }

  void set<T>(String key, T value) {
    switch (key) {
      case 'onboarded':
        onboarded = value as bool;
      case 'grid':
        grid = value as bool;
      case 'shutterSound':
        shutterSound = value as bool;
      case 'haptics':
        haptics = value as bool;
      case 'persist':
        persist = value as bool;
      case 'motion':
        motion = value as ClayMotionMode;
      default:
        return;
    }
    notifyListeners();
    _save(); // fire-and-forget: a gravação é de poucos bytes
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    notifyListeners();
    await _save();
  }
}
