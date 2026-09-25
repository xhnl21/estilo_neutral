import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/app/di/injection.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/core/router/app_router.dart';
import 'package:estilo_neutral/core/router/pages/not_found_page.dart';
import 'package:estilo_neutral/core/router/route_paths.dart';
import 'package:estilo_neutral/features/auth/application/auth_cubit.dart';
import 'package:estilo_neutral/presentation/pages/clientes_page.dart';
import 'package:estilo_neutral/presentation/pages/factura_detalle_page.dart';
import 'package:estilo_neutral/presentation/pages/inventario_page.dart';
import '../../test_fake_dio.dart';

/// `ServiceLocator().init()` dispara — sin esperarlo — el fetch inicial de
/// `SheetsDataService` (`initialize()`). Un `Future` real de dio creado
/// dentro del zone "fake async" de `testWidgets()` no llega a resolverse
/// nunca (es una limitación conocida de Flutter Test con async real, no un
/// bug de la app) y `pumpAndSettle()` se cuelga esperándolo. Por eso el
/// `init()` (la única llamada que realmente dispara ese fetch, gracias al
/// guard `_initialized` del singleton) se hace dentro de `tester.runAsync`,
/// que sí corre en una zone real — la función async que arranca ahí sigue
/// corriendo en esa misma zone después, aunque nadie la espere.
Future<void> _initServiceLocator(WidgetTester tester) {
  return tester.runAsync(() async {
    ServiceLocator().init(dio: buildFakeDio());
    // `init()` no espera a que termine `initialize()` (fetch en segundo
    // plano). Si lo dejamos "colgando", sigue corriendo durante los tests
    // siguientes y puede pisar su ventana de `pumpAndSettle()`. Como acá
    // estamos en la zone real de `runAsync`, sí podemos esperarlo bien.
    // `initialize()` recién pone `isLoading` en true DESPUÉS de su primer
    // `await` (token guardado), así que primero hay que esperar a que
    // arranque antes de esperar a que termine.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!ServiceLocator().sheetsDataService.isLoading && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 5));
    }
    while (ServiceLocator().sheetsDataService.isLoading) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    // Simula una sesión con organización activa (como ocurre siempre en la
    // app real tras el login) para que los getters filtrados por
    // organización (p.ej. `ventas`) expongan los datos semilla.
    ServiceLocator().sheetsDataService.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');
  });
}

void main() {
  group('AppRouter Widget Tests', () {
    testWidgets('navigates to initialLocation /ventas by default', (tester) async {
      await _initServiceLocator(tester);
      final authCubit = AuthCubit();
      final appRouter = AppRouter(
        authCubit: authCubit,
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
      await _initServiceLocator(tester);
      final authCubit = AuthCubit();
      final appRouter = AppRouter(
        authCubit: authCubit,
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
      await _initServiceLocator(tester);
      final authCubit = AuthCubit();
      final appRouter = AppRouter(
        authCubit: authCubit,
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
      await _initServiceLocator(tester);
      final authCubit = AuthCubit();
      final appRouter = AppRouter(
        authCubit: authCubit,
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
      await _initServiceLocator(tester);
      final authCubit = AuthCubit();
      final appRouter = AppRouter(
        authCubit: authCubit,
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
