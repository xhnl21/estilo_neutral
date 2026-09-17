import 'package:estilo_neutral/features/search/domain/entities/search_match.dart';
import 'package:estilo_neutral/features/search/presentation/widgets/search_highlighted_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchHighlightedText', () {
    testWidgets('renders plain text when highlightSpans is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchHighlightedText(
              text: 'Banco Provincial',
              highlightSpans: [],
            ),
          ),
        ),
      );

      expect(find.text('Banco Provincial'), findsOneWidget);
    });

    testWidgets('renders TextSpan tree with highlighted sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchHighlightedText(
              text: 'Banco de Venezuela',
              highlightSpans: [
                HighlightSpan(start: 9, end: 18), // 'Venezuela'
              ],
            ),
          ),
        ),
      );

      // Debe encontrar el widget RichText
      final textFinder = find.byType(RichText);
      expect(textFinder, findsOneWidget);

      final richText = tester.widget<RichText>(textFinder);
      final textSpan = richText.text as TextSpan;

      // Esperamos al menos 2 fragmentos: 'Banco de ' y 'Venezuela'
      expect(textSpan.children, isNotNull);
      expect(textSpan.children!.length, greaterThanOrEqualTo(2));

      final nonHighlighted = textSpan.children![0] as TextSpan;
      final highlighted = textSpan.children![1] as TextSpan;

      expect(nonHighlighted.text, equals('Banco de '));
      expect(highlighted.text, equals('Venezuela'));
      expect(highlighted.style?.fontWeight, equals(FontWeight.bold));
      expect(highlighted.style?.backgroundColor, isNotNull);
    });

    testWidgets('renders SizedBox.shrink on empty text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchHighlightedText(
              text: '',
              highlightSpans: [],
            ),
          ),
        ),
      );

      expect(find.byType(RichText), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });
}
