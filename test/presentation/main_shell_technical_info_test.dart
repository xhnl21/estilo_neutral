import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/app/di/injection.dart';
import 'package:estilo_neutral/core/config/environment_config.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/presentation/shell/main_shell.dart';

void main() {
  setUp(() {
    ServiceLocator().init();
  });

  tearDown(() {
    EnvironmentConfig.setOverrideShowTechnicalInfo(null);
  });

  testWidgets('MainShell hides sheet badge and DB metadata when showTechnicalInfo is false', (tester) async {
    EnvironmentConfig.setOverrideShowTechnicalInfo(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(
          dataService: ServiceLocator().sheetsDataService,
          authCubit: ServiceLocator().authCubit,
          sheetsAuth: ServiceLocator().sheetsAuth,
        ),
      ),
    );
    await tester.pump();

    // Verify technical metadata is NOT present in production mode
    expect(find.textContaining('Base de Datos Google Sheets'), findsNothing);
    expect(find.text('ventas'), findsNothing); // Badge in title
  });

  testWidgets('MainShell displays sheet badge and DB metadata when showTechnicalInfo is true', (tester) async {
    EnvironmentConfig.setOverrideShowTechnicalInfo(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(
          dataService: ServiceLocator().sheetsDataService,
          authCubit: ServiceLocator().authCubit,
          sheetsAuth: ServiceLocator().sheetsAuth,
        ),
      ),
    );
    await tester.pump();

    // Verify technical metadata IS present in dev/test mode
    expect(find.textContaining('Base de Datos Google Sheets'), findsOneWidget);
    expect(find.text('ventas'), findsOneWidget); // Badge in title for initial page (Ventas)
  });
}
