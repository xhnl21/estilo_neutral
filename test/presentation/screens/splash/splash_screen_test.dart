import 'package:estilo_neutral/core/design_system/tokens/colors.dart';
import 'package:estilo_neutral/presentation/screens/splash/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SplashScreen Tests', () {
    testWidgets('renders brand background and accessible skip button', (tester) async {
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            // Asset ficticio para validar resiliencia inmediata en test environment
            videoAsset: 'assets/non_existent.mp4',
            onVideoFinished: () => finished = true,
          ),
        ),
      );

      // Renderiza Scaffold con fondo institucional splashBackground (#D4C7B4)
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, equals(AppPalette.splashBackground));

      // Botón accesible de omitir con Semantics
      expect(find.bySemanticsLabel('Omitir video de introducción'), findsOneWidget);
      expect(find.text('Omitir'), findsOneWidget);

      // Resiliencia: la falla de carga del video ficticio ejecuta onVideoFinished
      await tester.pumpAndSettle();
      expect(finished, isTrue);
    });

    testWidgets('tapping skip button triggers onVideoFinished callback immediately', (tester) async {
      var skipTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            videoAsset: 'assets/estilo_neutral.mp4',
            onVideoFinished: () => skipTriggered = true,
          ),
        ),
      );

      final skipButton = find.text('Omitir');
      expect(skipButton, findsOneWidget);

      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(skipTriggered, isTrue);
    });
  });
}
