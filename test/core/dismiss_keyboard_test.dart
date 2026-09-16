import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/widgets/dismiss_keyboard.dart';

void main() {
  group('DismissKeyboard Widget Tests', () {
    testWidgets('unfocuses primary focus when tapping empty area', (tester) async {
      final FocusNode focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => DismissKeyboard(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  focusNode: focusNode,
                  autofocus: true,
                ),
                Container(
                  key: const Key('empty-space'),
                  color: Colors.transparent,
                  height: 200,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify textfield has focus initially
      expect(focusNode.hasFocus, isTrue);

      // Tap on empty space outside TextField
      await tester.tap(find.byKey(const Key('empty-space')));
      await tester.pump();

      // Focus should be dismissed
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('allows interaction with buttons without blocking', (tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DismissKeyboard(
            child: Scaffold(
              body: ElevatedButton(
                onPressed: () => buttonPressed = true,
                child: const Text('Acción'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Acción'));
      await tester.pump();

      expect(buttonPressed, isTrue);
    });
  });
}
