import 'package:flutter/material.dart';
import 'di/injection.dart';
import '../features/sales/presentation/pages/sales_page.dart';

class EstiloNeutralApp extends StatelessWidget {
  const EstiloNeutralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estilo Neutral',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B365D),
          primary: const Color(0xFF1B365D),
        ),
      ),
      home: SalesPage(
        controller: ServiceLocator().salesController,
      ),
    );
  }
}
