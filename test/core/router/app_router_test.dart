import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/app/di/injection.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/core/router/app_router.dart';
import 'package:estilo_neutral/core/router/pages/not_found_page.dart';
import 'package:estilo_neutral/core/router/route_paths.dart';
import 'package:estilo_neutral/features/auth/application/auth_notifier.dart';
import 'package:estilo_neutral/features/sales/presentation/pages/sale_detail_page.dart';
import 'package:estilo_neutral/presentation/pages/clientes_page.dart';
import 'package:estilo_neutral/presentation/pages/inventario_page.dart';

void main() {
  setUp(() {
    ServiceLocator().init();
  });

  group('AppRouter Widget Tests', () {
    testWidgets('navigates to initialLocation /ventas by default', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        salesController: ServiceLocator().salesController,
        dataService: ServiceLocator().sheetsDataService,
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
        salesController: ServiceLocator().salesController,
        dataService: ServiceLocator().sheetsDataService,
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

    testWidgets('supports deep linking to /ventas/:id with SaleDetailPage', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        salesController: ServiceLocator().salesController,
        dataService: ServiceLocator().sheetsDataService,
        initialLocation: RoutePaths.buildSaleDetailPath('v00000001'),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleDetailPage), findsOneWidget);
      expect(find.text('Detalle de Venta #v00000001'), findsOneWidget);
    });

    testWidgets('supports deep linking with query parameters on /inventario?q=Pantalon', (tester) async {
      final authNotifier = AuthNotifier();
      final appRouter = AppRouter(
        authNotifier: authNotifier,
        salesController: ServiceLocator().salesController,
        dataService: ServiceLocator().sheetsDataService,
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
        salesController: ServiceLocator().salesController,
        dataService: ServiceLocator().sheetsDataService,
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
