import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/theme/kame_theme.dart';
import 'package:kame_io/widgets/glass_bottom_nav.dart';

void main() {
  const destinations = <KameDestination>[
    KameDestination(label: 'Câmera', icon: Icons.photo_camera_outlined),
    KameDestination(
      label: 'Galeria',
      icon: Icons.photo_library_outlined,
      activeIcon: Icons.photo_library,
    ),
    KameDestination(label: 'Ajustes', icon: Icons.tune_rounded),
  ];

  Widget wrap({required int index, required ValueChanged<int> onChanged}) {
    return MaterialApp(
      theme: KameTheme.dark(),
      home: Scaffold(
        bottomNavigationBar: GlassBottomNav(
          index: index,
          destinations: destinations,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('renders every destination label', (tester) async {
    await tester.pumpWidget(wrap(index: 0, onChanged: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Câmera'), findsOneWidget);
    expect(find.text('Galeria'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int tapped = -1;
    await tester.pumpWidget(wrap(index: 0, onChanged: (i) => tapped = i));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(tapped, 2);

    await tester.tap(find.text('Galeria'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('selected destination swaps to its filled/active icon',
      (tester) async {
    await tester.pumpWidget(wrap(index: 1, onChanged: (_) {}));
    await tester.pumpAndSettle();

    // "Galeria" is selected -> its activeIcon; the others keep the outline.
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });
}
