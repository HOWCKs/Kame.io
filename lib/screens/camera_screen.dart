import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/kame_theme.dart';

/// Live viewfinder with capture / lens switch / flash controls.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.onOpenGallery});

  /// Optional shortcut to the gallery tab (wired by [HomeShell]).
  final VoidCallback? onOpenGallery;

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
  bool _front = false;
  FlashMode _flash = FlashMode.off;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
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
      _front = description.lensDirection == CameraLensDirection.front;
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
    if (_cameras.length < 2 || _busy) return;
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

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Foto salva em ${file.path}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: KameTokens.surface,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao capturar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData get _flashIcon => switch (_flash) {
        FlashMode.torch => Icons.flashlight_on_rounded,
        FlashMode.auto => Icons.flash_auto_rounded,
        _ => Icons.flash_off_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.4, -0.8),
          radius: 1.3,
          colors: [Color(0xFF161D38), KameTokens.background],
        ),
      ),
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
                children: [
                  const Text(
                    'Kame.io',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _front ? 'frontal' : 'traseira',
                    style: const TextStyle(
                      color: KameTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (_cameras.isNotEmpty)
                    IconButton(
                      onPressed: _cycleFlash,
                      icon: Icon(_flashIcon),
                      color: _flash == FlashMode.off
                          ? KameTokens.muted
                          : KameTokens.primary,
                      tooltip: 'Flash',
                    ),
                ],
              ),
            ),
            Expanded(child: _buildViewfinder()),
            _buildControls(),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KameTokens.gap),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KameTokens.radiusCard),
        child: CameraPreview(camera),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KameTokens.gap * 2,
        KameTokens.gap,
        KameTokens.gap * 2,
        108, // clearance for the floating nav bar
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassIconButton(
            icon: Icons.photo_library_outlined,
            onTap: widget.onOpenGallery ?? () {},
            enabled: widget.onOpenGallery != null,
          ),
          GestureDetector(
            onTap: _busy ? null : _capture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KameTokens.onSurface, width: 3),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: KameTokens.fast,
                  width: _busy ? 30 : 60,
                  height: _busy ? 30 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _busy ? KameTokens.muted : KameTokens.onSurface,
                  ),
                ),
              ),
            ),
          ),
          _GlassIconButton(
            icon: Icons.cameraswitch_outlined,
            onTap: _switchLens,
            enabled: _cameras.length > 1 && !_busy,
          ),
        ],
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: KameTokens.glassFill,
        shape: const CircleBorder(
          side: BorderSide(color: KameTokens.glassStroke),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: KameTokens.onSurface),
          ),
        ),
      ),
    );
  }
}
