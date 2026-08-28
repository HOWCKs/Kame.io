import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';
import '../widgets/notched_camera_bar.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

/// Tela principal: viewfinder em tela cheia + barra "notch" de controle.
/// Configurações e galeria abrem como overlays por cima da câmera, que
/// continua viva embaixo.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _lens = 0;
  bool _ready = false;
  bool _busy = false;
  FlashMode _flash = FlashMode.off;
  CaptureMode _mode = CaptureMode.foto;
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  String? _error;
  XFile? _lastMedia;
  final List<XFile> _gallery = [];
  bool _showSettings = false;
  bool _showGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() => _ready = false);
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _open(_cameras[_lens]);
    }
  }

  Future<void> _bootstrap() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      if (!mounted) return; // widget disposed before the platform replied
      setState(() => _error = 'Não foi possível listar as câmeras: $e');
      return;
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _error = 'Nenhuma câmera disponível neste dispositivo.');
      return;
    }
    await _open(_cameras[_lens]);
  }

  Future<void> _open(CameraDescription description) async {
    final previous = _controller;
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    setState(() {
      _ready = false;
      _error = null;
    });

    try {
      await controller.initialize();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha ao iniciar a câmera: $e');
      return;
    }

    await previous?.dispose();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _switchLens() async {
    if (_cameras.length < 2 || _busy || _recording) return;
    setState(() {
      _busy = true;
      _lens = (_lens + 1) % _cameras.length;
    });
    await _open(_cameras[_lens]);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    const order = <FlashMode>[FlashMode.off, FlashMode.auto, FlashMode.torch];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flash = next);
    } catch (_) {
      // Torch unsupported on this device — keep the previous mode.
    }
  }

  Future<void> _onShutter() async {
    if (_mode == CaptureMode.foto) {
      await _capturePhoto();
    } else {
      await _toggleRecording();
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      _gallery.insert(0, file);
      _lastMedia = file;
      _snack('Foto salva em ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao capturar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    if (!_recording) {
      setState(() => _busy = true);
      try {
        await controller.startVideoRecording();
        _recSeconds = 0;
        _recTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() => _recSeconds++),
        );
        if (mounted) setState(() => _recording = true);
      } catch (e) {
        if (mounted) _snack('Erro ao gravar: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    _recTimer?.cancel();
    setState(() => _busy = true);
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      _gallery.insert(0, file);
      _lastMedia = file;
      _snack('Vídeo salvo em ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao parar a gravação: $e');
    } finally {
      if (mounted) setState(() { _recording = false; _busy = false; });
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: KameTokens.surface,
        ),
      );
  }

  String get _recLabel {
    final m = (_recSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KameTokens.background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildViewfinder()),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(bottom: false, child: _buildTopBar()),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: NotchedCameraBar(
                mode: _mode,
                recording: _recording,
                flash: _flash,
                onModeChanged: (m) => setState(() => _mode = m),
                onShutter: _onShutter,
                onFlip: _switchLens,
                onFlash: _cycleFlash,
                onConfig: () => setState(() => _showSettings = true),
              ),
            ),
          ),
          if (_showSettings) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showSettings = false),
                child: const ColoredBox(color: Color(0x80000000)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SettingsSheet(
                onClose: () => setState(() => _showSettings = false),
              ),
            ),
          ],
          if (_showGallery)
            Positioned.fill(
              child: GalleryScreen(
                initialItems: _gallery,
                onClose: () => setState(() => _showGallery = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    final camera = _controller;
    if (_error != null) {
      return _Message(icon: Icons.videocam_off_outlined, text: _error!);
    }
    if (camera == null || !_ready || !camera.value.isInitialized) {
      return const _Message(
        icon: Icons.photo_camera_outlined,
        text: 'Iniciando a câmera…',
        spinner: true,
      );
    }
    return CameraPreview(camera);
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Última foto/vídeo — abre a galeria.
          GestureDetector(
            onTap: () => setState(() => _showGallery = true),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KameTokens.glassStroke),
                color: KameTokens.glassFill,
              ),
              clipBehavior: Clip.antiAlias,
              child: _lastMedia == null
                  ? const Icon(
                      Icons.photo_library_outlined,
                      size: 20,
                      color: KameTokens.muted,
                    )
                  : _thumb(_lastMedia!),
            ),
          ),
          const Spacer(),
          if (_recording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xB3000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: NotchedCameraBar.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _recLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              ),
          const SizedBox(width: 8),
          const Text(
            'Kame.io',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _thumb(XFile file) {
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
      return const Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Color(0xFF20263E))),
          Center(
            child: Icon(Icons.videocam_rounded, size: 20, color: KameTokens.primary),
          ),
        ],
      );
    }
    return Image.file(
      File(file.path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => const Icon(
        Icons.broken_image_outlined,
        size: 20,
        color: KameTokens.muted,
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: 460 + bottom,
        color: KameTokens.surface,
        child: Stack(
          children: [
            const Positioned.fill(child: SettingsScreen(embedded: true)),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                color: KameTokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.spinner = false});

  final IconData icon;
  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: KameTokens.muted),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KameTokens.muted),
            ),
            if (spinner) ...[
              const SizedBox(height: 20),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
