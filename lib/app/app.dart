import 'package:flutter/material.dart';
import '../core/design_system/theme/app_theme.dart';
import '../presentation/shell/main_shell.dart';
import 'di/injection.dart';

/// Aplicación principal Estilo Neutral.
/// Configurada con el sistema de diseño visual minimalista, paleta azul y CupertinoIcons.
class EstiloNeutralApp extends StatelessWidget {
  const EstiloNeutralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estilo Neutral',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: MainShell(
        salesController: ServiceLocator().salesController,
        dataService: ServiceLocator().sheetsDataService,
      ),
    );
  }
}
