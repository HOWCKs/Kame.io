import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'theme/kame_theme.dart';

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
      home: const CameraScreen(),
    );
  }
}
