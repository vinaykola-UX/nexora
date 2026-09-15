import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/chat/presentation/widgets/markdown_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NexoraMarkdownRenderer Tests', () {
    testWidgets('Renders empty text gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NexoraMarkdownRenderer(text: ''),
          ),
        ),
      );

      expect(find.byType(NexoraMarkdownRenderer), findsOneWidget);
    });

    testWidgets('Renders standard paragraph text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NexoraMarkdownRenderer(text: 'Data structures represent ways of organizing data.'),
          ),
        ),
      );

      expect(find.textContaining('Data structures represent ways of organizing data.'), findsOneWidget);
    });

    testWidgets('Renders headings with correct hierarchy', (WidgetTester tester) async {
      const markdown = '# Main Heading\n## Sub Heading\n### Topic Heading';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NexoraMarkdownRenderer(text: markdown),
          ),
        ),
      );

      expect(find.text('Main Heading'), findsOneWidget);
      expect(find.text('Sub Heading'), findsOneWidget);
      expect(find.text('Topic Heading'), findsOneWidget);
    });

    testWidgets('Renders bullet and numbered list items', (WidgetTester tester) async {
      const markdown = '- First item\n- Second item\n1. Numbered one\n2. Numbered two';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NexoraMarkdownRenderer(text: markdown),
          ),
        ),
      );

      expect(find.textContaining('First item'), findsOneWidget);
      expect(find.textContaining('Second item'), findsOneWidget);
      expect(find.textContaining('Numbered one'), findsOneWidget);
      expect(find.textContaining('Numbered two'), findsOneWidget);
    });

    testWidgets('Renders code block with language tag', (WidgetTester tester) async {
      const markdown = '```dart\nvoid main() {\n  print("Hello Nexora");\n}\n```';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NexoraMarkdownRenderer(text: markdown),
          ),
        ),
      );

      expect(find.text('DART'), findsOneWidget);
      expect(find.textContaining('Hello Nexora'), findsOneWidget);
      expect(find.text('Copy code'), findsOneWidget);
    });

    testWidgets('Renders table elements without crashing', (WidgetTester tester) async {
      const markdown =
          '| Subject | Credits |\n| --- | --- |\n| Data Structures | 4 |\n| DBMS | 3 |';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NexoraMarkdownRenderer(text: markdown),
          ),
        ),
      );

      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('DBMS'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });
  });
}
