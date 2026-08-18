// Basic smoke test for the Nexora app.
//
// The previous version was still the default Flutter counter-app boilerplate
// (referenced MyApp and counter UI, neither of which exist in Nexora), so
// flutter analyze/flutter test failed on it. This mirrors the real bootstrap
// in main.dart (NexoraApp wrapped in ProviderScope) and checks it mounts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexora/main.dart';

void main() {
  testWidgets('NexoraApp builds and renders its initial route without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NexoraApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
