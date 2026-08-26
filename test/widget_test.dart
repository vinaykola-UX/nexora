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
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
