import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/app/di/injection.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/core/router/app_router.dart';
import 'package:estilo_neutral/core/router/pages/not_found_page.dart';
import 'package:estilo_neutral/core/router/route_paths.dart';
import 'package:estilo_neutral/features/auth/application/auth_notifier.dart';
import 'package:estilo_neutral/presentation/pages/clientes_page.dart';
import 'package:estilo_neutral/presentation/pages/factura_detalle_page.dart';
import 'package:estilo_neutral/presentation/pages/inventario_page.dart';

void main() {
  setUp(() {
    ServiceLocator().init();
    // Simula una sesión con organización activa (como ocurre siempre en la
    // app real tras el login) para que los getters filtrados por
    // organización (p.ej. `ventas`) expongan los datos semilla.
    ServiceLocator().sheetsDataService.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');
  });

  group('AppRouter Widget Tests', () {
    testWidgets('navigates to initialLocation /ventas by default', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        dataService: ServiceLocator().sheetsDataService,
        sheetsAuth: ServiceLocator().sheetsAuth,
        initialLocation: RoutePaths.ventas,
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      // Should be in Ventas
      expect(find.text('Ventas'), findsWidgets);
    });

    testWidgets('renders NotFoundPage when navigating to an unknown route', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        dataService: ServiceLocator().sheetsDataService,
        sheetsAuth: ServiceLocator().sheetsAuth,
        initialLocation: '/ruta-desconocida-xyz',
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotFoundPage), findsOneWidget);
      expect(find.text('Página No Encontrada (404)'), findsOneWidget);
    });

    testWidgets('supports deep linking to /ventas/:id with FacturaDetallePage', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        dataService: ServiceLocator().sheetsDataService,
        sheetsAuth: ServiceLocator().sheetsAuth,
        initialLocation: RoutePaths.buildSaleDetailPath('v00000001'),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FacturaDetallePage), findsOneWidget);
      expect(find.text('Factura #v00000001'), findsOneWidget);
    });

    testWidgets('supports deep linking with query parameters on /inventario?q=Pantalon', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        dataService: ServiceLocator().sheetsDataService,
        sheetsAuth: ServiceLocator().sheetsAuth,
        initialLocation: '${RoutePaths.inventario}?q=Pantalon',
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InventarioPage), findsOneWidget);
    });

    testWidgets('persists StatefulShellRoute across tab navigation', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        dataService: ServiceLocator().sheetsDataService,
        sheetsAuth: ServiceLocator().sheetsAuth,
        initialLocation: RoutePaths.ventas,
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Ventas
      expect(appRouter.router.state.matchedLocation, equals(RoutePaths.ventas));

      // Navigate to Clientes
      appRouter.router.go(RoutePaths.clientes);
      await tester.pumpAndSettle();

      expect(find.byType(ClientesPage), findsOneWidget);
      expect(appRouter.router.state.matchedLocation, equals(RoutePaths.clientes));
    });
  });
}
