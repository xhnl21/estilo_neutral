import 'package:flutter/material.dart';
import '../core/design_system/design_system.dart';
import 'di/injection.dart';

/// Aplicación principal Estilo Neutral.
/// Configurada con el sistema de diseño visual minimalista, paleta azul y CupertinoIcons.
class EstiloNeutralApp extends StatelessWidget {
  const EstiloNeutralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Estilo Neutral',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: ServiceLocator().appRouter.router,
      builder: (context, child) {
        return DismissKeyboard(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}


