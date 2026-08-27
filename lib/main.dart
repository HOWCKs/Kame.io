import 'package:flutter/material.dart';

import 'theme/kame_theme.dart';
import 'widgets/glass_bottom_nav.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KameApp());
}

class KameApp extends StatelessWidget {
  const KameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kame.io',
      debugShowCheckedModeBanner: false,
      theme: KameTheme.dark(),
      home: const HomeShell(),
    );
  }
}

/// Scaffold that owns the bottom navigation and the three destination pages.
///
/// [IndexedStack] keeps every page alive so the camera preview is not torn
/// down (and the permission is not re-requested) when switching tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = <KameDestination>[
    KameDestination(label: 'Câmera', icon: Icons.photo_camera_outlined, activeIcon: Icons.photo_camera),
    KameDestination(label: 'Galeria', icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library),
    KameDestination(label: 'Ajustes', icon: Icons.tune_rounded, activeIcon: Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // content scrolls under the translucent nav bar
      body: IndexedStack(
        index: _index,
        children: [
          CameraScreen(onOpenGallery: () => setState(() => _index = 1)),
          const GalleryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        index: _index,
        destinations: _destinations,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }
}
