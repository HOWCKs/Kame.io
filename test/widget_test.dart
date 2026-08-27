import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kame_io/theme/kame_theme.dart';

void main() {
  testWidgets('Kame.io boots with the dark Material 3 theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: KameTheme.dark(), home: const Scaffold(body: Text('ok'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('ok'), findsOneWidget);

    final theme = Theme.of(tester.element(find.text('ok')));
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, KameTokens.primary);
    expect(theme.scaffoldBackgroundColor, KameTokens.background);
  });
}
