import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../icons/clay_glyphs.dart';
import '../motion/clay_motion.dart';
import '../navigation/clay_route.dart';
import '../services/clay_settings.dart';
import '../services/morph_vault.dart';
import '../shape/clay_squircle.dart';
import '../theme/clay_tokens.dart';
import '../widgets/clay_control_bar.dart';
import '../widgets/clay_controls.dart';
import '../widgets/clay_glyph_view.dart';
import '../widgets/clay_states.dart';
import '../widgets/clay_surface.dart';
import '../widgets/clay_toast.dart';
import 'atlas_screen.dart';
import 'settings_screen.dart';

/// O Estúdio: onde a matéria é capturada.
///
/// Hierarquia intencional — o viewfinder ocupa tudo e os controles boiam sobre
/// ele. Nada disputa atenção com a imagem: barra e topo são porcelana sobre
/// sombra, e o único ponto quente (esmalte) é o obturador.
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.settings,
    required this.vault,
  });

  final ClaySettings settings;
  final MorphVault vault;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _lens = 0;
  bool _ready = false;
  bool _busy = false;
  FlashMode _flash = FlashMode.off;
  CaptureMode _mode = CaptureMode.foto;
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  Timer? _zoomTimer;
  String? _error;
  XFile? _lastMedia;
  bool _audioReady = false;

  int _pulse = 0;
  int _toastId = 0;
  ClayToastRequest? _toast;

  double _zoom = 1;
  double _zoomBase = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  bool _zoomSupported = false;
  bool _zoomVisible = false;

  Offset? _focusPoint;
  int _focusId = 0;
  Timer? _focusTimer;
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _zoomTimer?.cancel();
    _focusTimer?.cancel();
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
      _open(_cameras[_lens], audio: _audioReady);
    }
  }

  // ── Ciclo da câmera ──────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'cameras:$e');
      return;
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _error = 'empty');
      return;
    }
    await _open(_cameras[_lens]);
  }

  Future<void> _open(CameraDescription description, {bool audio = false}) async {
    final previous = _controller;
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: audio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    setState(() {
      _ready = false;
      _error = null;
    });

    try {
      await controller.initialize();
      await _readZoomRange(controller);
      if (mounted) {
        setState(() {
          _ready = true;
          _audioReady = audio;
          _zoom = 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'open:$e');
      return;
    }

    await previous?.dispose();
  }

  Future<void> _readZoomRange(CameraController controller) async {
    try {
      final min = await controller.getMinZoomLevel();
      final max = await controller.getMaxZoomLevel();
      if (!mounted) return;
      setState(() {
        _minZoom = min;
        _maxZoom = max;
        _zoomSupported = max > min + 0.01;
      });
    } catch (_) {
      // Zoom não é suportado neste dispositivo: o gesto simplesmente não age.
      if (mounted) setState(() => _zoomSupported = false);
    }
  }

  Future<void> _switchLens() async {
    if (_cameras.length < 2 || _busy || _recording) return;
    ClayHaptics.settle(context);
    setState(() {
      _busy = true;
      _lens = (_lens + 1) % _cameras.length;
    });
    await _open(_cameras[_lens], audio: _audioReady);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    const order = <FlashMode>[FlashMode.off, FlashMode.auto, FlashMode.torch];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    try {
      await controller.setFlashMode(next);
      if (mounted) {
        ClayHaptics.tap(context);
        setState(() => _flash = next);
      }
    } catch (_) {
      // Lanterna indisponível: mantém o modo anterior sem derrubar a tela.
    }
  }

  Future<void> _setMode(CaptureMode mode) async {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    ClayHaptics.tap(context);
    if (mode == CaptureMode.video) await _ensureAudio();
  }

  /// Vídeo sem áudio é meia experiência. O pedido do microfone acontece
  /// **no momento em que o usuário escolhe vídeo** — não no boot, quando
  /// ninguém entende por que o sistema está pedindo permissão.
  Future<void> _ensureAudio() async {
    if (_audioReady) return;
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        status = await Permission.microphone.request();
      }
      if (!mounted) return;
      if (status.isGranted && _cameras.isNotEmpty) {
        await _open(_cameras[_lens], audio: true);
      } else {
        _toastNow(
          message: 'Gravando sem áudio. Libere o microfone nos ajustes do sistema.',
          glyph: ClayGlyphs.wave(),
        );
      }
    } catch (_) {
      // Sem o plugin de permissão, seguimos sem áudio — o vídeo ainda sai.
    }
  }

  // ── Captura ──────────────────────────────────────────────────────────────

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
    setState(() {
      _busy = true;
      _pulse = _pulse + 1;
    });
    if (widget.settings.shutterSound) {
      await SystemSound.play(SystemSoundType.click);
    }
    ClayHaptics.shape(context);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      final item = await widget.vault.add(
        file,
        persist: widget.settings.persist,
      );
      if (!mounted) return;
      setState(() => _lastMedia = file);
      if (item == null) {
        _toastNow(
          message: 'A forma não foi guardada. Verifique o armazenamento.',
          glyph: ClayGlyphs.trash(),
        );
      } else {
        _toastNow(
          message: 'Forma guardada no Atlas.',
          glyph: ClayGlyphs.check(),
          actionLabel: 'Ver',
          onAction: _openAtlas,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _toastNow(message: 'Não foi possível capturar: $e');
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
          (_) {
            if (mounted) setState(() => _recSeconds++);
          },
        );
        if (mounted) setState(() => _recording = true);
        ClayHaptics.shape(context);
      } catch (e) {
        if (mounted) _toastNow(message: 'Não foi possível gravar: $e');
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
      final item = await widget.vault.add(
        file,
        persist: widget.settings.persist,
      );
      if (!mounted) return;
      setState(() => _lastMedia = file);
      _toastNow(
        message: item == null
            ? 'A gravação não foi guardada.'
            : 'Gravação guardada no Atlas.',
        glyph: item == null ? ClayGlyphs.trash() : ClayGlyphs.check(),
        actionLabel: item == null ? null : 'Ver',
        onAction: item == null ? null : _openAtlas,
      );
    } catch (e) {
      if (mounted) _toastNow(message: 'Não foi possível parar a gravação: $e');
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
        });
      }
    }
  }

  // ── Gestos ───────────────────────────────────────────────────────────────

  void _focusAt(TapUpDetails details) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final local = details.localPosition;
    setState(() {
      _focusPoint = local;
      _focusId++;
    });
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _focusPoint = null);
    });

    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    // Normalizado para a caixa da pré-visualização (0..1), como o plugin espera.
    final size = box.size;
    final relative = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    _guarded(() => controller.setFocusPoint(relative));
    _guarded(() => controller.setExposurePoint(relative));
  }

  Future<void> _guarded(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Foco/exposto por ponto não existe em todo dispositivo Android; a
      // ausência do recurso não pode virar erro de usuário.
    }
  }

  void _scaleStart(ScaleStartDetails details) => _zoomBase = _zoom;

  void _scaleUpdate(ScaleUpdateDetails details) {
    if (!_zoomSupported) return;
    final next = (_zoomBase * details.scale).clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.005) return;
    setState(() {
      _zoom = next;
      _zoomVisible = true;
    });
    final controller = _controller;
    if (controller != null) _guarded(() => controller.setZoomLevel(next));
    _zoomTimer?.cancel();
    _zoomTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _zoomVisible = false);
    });
  }

  // ── Navegação e feedback ─────────────────────────────────────────────────

  void _toastNow({
    required String message,
    List<ClayStroke>? glyph,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _toastId++;
    setState(() {
      _toast = ClayToastRequest(
        id: _toastId,
        message: message,
        glyph: glyph,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    });
  }

  void _openAtlas() {
    Navigator.of(context).push(
      ClayPageRoute<void>(
        settings: const RouteSettings(name: '/atlas'),
        motion: ClayMotionScope.of(context),
        builder: (_) => AtlasScreen(settings: widget.settings, vault: widget.vault),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      ClayPageRoute<void>(
        settings: const RouteSettings(name: '/settings'),
        motion: ClayMotionScope.of(context),
        builder: (_) => SettingsScreen(settings: widget.settings, vault: widget.vault),
      ),
    );
  }

  Future<void> _openSystemSettings() => openAppSettings();

  String get _recLabel {
    final m = (_recSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Árvore ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 700;

    return Scaffold(
      backgroundColor: ClayPalette.abyss,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildStage(wide)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _buildTopBar(),
                ),
              ),
            ),
          ),
          if (_zoomVisible && _zoomSupported)
            Positioned(
              right: ClaySpace.md,
              bottom: ClayControlBar.totalHeight + ClaySpace.lg,
              child: ClayChip(
                label: '${_zoom.toStringAsFixed(1)}×',
                tone: ClayPalette.chalk,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: ClaySpace.sm + 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClaySpace.gutter,
                    ),
                    child: ClayToastOverlay(request: _toast),
                  ),
                  const SizedBox(height: ClaySpace.sm),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ClaySpace.gutter,
                        ),
                        child: ClayControlBar(
                          mode: _mode,
                          recording: _recording,
                          flash: _flash,
                          ready: _ready,
                          pulse: _pulse,
                          onModeChanged: _setMode,
                          onShutter: _onShutter,
                          onFlip: _switchLens,
                          onFlash: _cycleFlash,
                          onSettings: _openSettings,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage(bool wide) {
    final child = _buildViewfinder();
    if (!wide) return child;
    return Container(
      color: ClayPalette.bedrock,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ClaySpace.lg,
            ClaySpace.xl,
            ClaySpace.lg,
            0,
          ),
          child: ClipPath(
            clipper: _SquircleStageClipper(ClayRadii.sheet),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    final camera = _controller;
    if (_error != null) return _buildError();
    if (camera == null || !_ready || !camera.value.isInitialized) {
      return const ClayBooting();
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          key: _previewKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _focusAt,
            onScaleStart: _scaleStart,
            onScaleUpdate: _scaleUpdate,
            child: CameraPreview(camera),
          ),
        ),
        if (widget.settings.grid) const ClayGridOverlay(),
        if (_focusPoint != null)
          ClayFocusRing(key: ValueKey<int>(_focusId), position: _focusPoint!),
      ],
    );
  }

  /// A mensagem traduz o código técnico em causa e saída — nunca exibe o
  /// texto cru da exceção, que não diz nada a quem usa o app.
  Widget _buildError() {
    final code = _error ?? '';
    if (code == 'empty') {
      return ClayErrorState(
        title: 'Nenhuma câmera por aqui',
        message:
            'Este aparelho não expôs nenhuma lente ao Kame.io. Feche outros apps de câmera e tente de novo.',
        actionLabel: 'Tentar de novo',
        onAction: _bootstrap,
      );
    }
    return ClayErrorState(
      title: 'A câmera não abriu',
      message: code.startsWith('open:') || code.startsWith('cameras:')
          ? 'O sistema negou o acesso à lente. Dê a permissão de câmera nos ajustes e a matéria volta a esquentar.'
          : 'Algo travou o caminho entre o app e a lente. Reabrir costuma resolver.',
      actionLabel: 'Tentar de novo',
      onAction: _bootstrap,
      secondaryLabel: 'Abrir ajustes',
      onSecondary: _openSystemSettings,
    );
  }

  Widget _buildTopBar() {
    final last = _lastMedia;
    final count = widget.vault.items.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClaySpace.gutter,
        ClaySpace.sm,
        ClaySpace.gutter,
        ClaySpace.sm,
      ),
      child: Row(
        children: <Widget>[
          _ThumbTile(
            path: last?.path,
            video: last != null && MorphVault.isVideo(last.path),
            count: count,
            onTap: _openAtlas,
          ),
          const Spacer(),
          if (_recording)
            ClayChip(
              label: _recLabel,
              glyph: ClayGlyphs.timer(),
              tone: ClayPalette.ember,
            ),
          if (!_recording)
            Text(
              'KAME.IO',
              style: ClayType.micro(color: ClayPalette.smoke, size: 10),
            ),
        ],
      ),
    );
  }
}

/// Miniatura da última forma + contador do Atlas.
class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.onTap,
    this.path,
    this.video = false,
    this.count = 0,
  });

  final String? path;
  final bool video;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ClaySurface(
          width: 46,
          height: 46,
          radius: ClayRadii.chip + 2,
          padding: EdgeInsets.zero,
          elevation: ClayElevation.l1,
          semanticLabel: 'Abrir o Atlas',
          tooltip: 'Abrir o Atlas',
          onTap: onTap,
          child: ClipPath(
            clipper: _SquircleStageClipper(ClayRadii.chip),
            child: path == null
                ? Center(
                    child: ClayGlyphView(
                      glyph: ClayGlyphs.stack(),
                      size: 20,
                      color: ClayPalette.inkSoft,
                    ),
                  )
                : (video
                    ? Container(
                        color: ClayPalette.clayMid,
                        alignment: Alignment.center,
                        child: ClayGlyphView(
                          glyph: ClayGlyphs.reel(),
                          size: 20,
                          color: ClayPalette.porcelain,
                        ),
                      )
                    : Image.file(
                        File(path!),
                        fit: BoxFit.cover,
                        width: 46,
                        height: 46,
                        errorBuilder: (_, __, ___) => Container(
                          color: ClayPalette.clayMid,
                          alignment: Alignment.center,
                          child: ClayGlyphView(
                            glyph: ClayGlyphs.cameraOff(),
                            size: 20,
                            color: ClayPalette.ash,
                          ),
                        ),
                      )),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: ClaySurface(
              pressable: false,
              kind: ClayMaterialKind.glaze,
              radius: ClayRadii.pill,
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: ClayType.micro(color: Colors.white, size: 10),
              ),
            ),
          ),
      ],
    );
  }
}

/// Grade dos terços desenhada sobre o viewfinder.
class ClayGridOverlay extends StatelessWidget {
  const ClayGridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final motion = ClayMotionScope.of(context);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: const Tween<double>(begin: 0, end: 1),
        duration: motion.d(ClayDurations.morph),
        curve: motion.curve(ClayCurves.softOut),
        builder: (context, t, _) {
          return Opacity(
            opacity: 0.28 * t,
            child: CustomPaint(painter: _GridPainter(inset: 14 * (1 - t))),
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({this.inset = 0});

  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    final left = inset;
    final right = size.width - inset;
    final top = inset;
    final bottom = size.height - inset;
    final w = right - left;
    final h = bottom - top;

    for (var i = 1; i <= 2; i++) {
      final x = left + (w / 3) * i;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
      final y = top + (h / 3) * i;
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.inset != inset;
}

/// Recorte em squircle reutilizado por palco e miniaturas.
class _SquircleStageClipper extends CustomClipper<Path> {
  _SquircleStageClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) =>
      ClayShape.squircle(Offset.zero & size, radius);

  @override
  bool shouldReclip(covariant _SquircleStageClipper oldClipper) =>
      oldClipper.radius != radius;
}
