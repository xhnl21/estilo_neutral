import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/models/producto.dart';
import 'package:estilo_neutral/presentation/pages/ventas_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

/// Reproduce el flujo real: el modal "Registrar Venta" vive en la rama de
/// Ventas de un StatefulShellRoute (la barra inferior sigue visible), con el
/// menú de clientes abierto; el usuario cambia a la pestaña Clientes, edita
/// o elimina un cliente, y vuelve.
void main() {
  const org = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';
  late SheetsDataService service;

  Cliente cliente(String id, String nombre) => Cliente(
        id: id,
        nombre: nombre,
        telefono: '',
        email: '',
        saldoDeudaUsd: 0,
        fechaRegistro: DateTime(2026, 10, 6),
      );

  setUp(() async {
    (service, _) = await servicioConServidor(inicializar: false);
    service.setCurrentOrganizacion(org);
    await service.addCliente(cliente('c90000001', 'Neida'));
    await service.addCliente(cliente('c90000002', 'Neyza'));
    await service.addCliente(cliente('c90000003', 'Zayda'));
    await service.addProducto(const Producto(
      id: 'p90000001',
      cantidad: 5,
      nombre: 'Camisa',
      marca: 'M',
      modelo: 'X',
      talla: 'M',
      precioUsd: 10,
    ));
  });

  Future<StatefulNavigationShell> pumpShell(WidgetTester tester) async {
    late StatefulNavigationShell shell;
    final router = GoRouter(
      initialLocation: '/ventas',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return Scaffold(body: navigationShell);
          },
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/clientes', builder: (_, __) => const Text('pestaña clientes')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/ventas', builder: (_, __) => VentasPage(dataService: service)),
            ]),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    return shell;
  }

  Future<void> abrirMenuClientes(WidgetTester tester) async {
    await tester.tap(find.text('Nueva Venta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neida (c90000001)'));
    await tester.pumpAndSettle();
  }

  testWidgets('editar un cliente con el menú abierto actualiza las opciones', (tester) async {
    final shell = await pumpShell(tester);
    await abrirMenuClientes(tester);
    expect(find.text('Neyza (c90000002)'), findsWidgets);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    final neyza = service.clientes.firstWhere((c) => c.id == 'c90000002');
    await tester.runAsync(() => service.updateCliente(neyza.copyWith(nombre: 'Neyza Editada')));
    shell.goBranch(1);
    await tester.pumpAndSettle();

    // El menú desactualizado se cerró; al reabrirlo muestra el nombre nuevo.
    expect(find.text('Neyza (c90000002)'), findsNothing);
    await tester.tap(find.text('Neida (c90000001)'));
    await tester.pumpAndSettle();
    expect(find.text('Neyza Editada (c90000002)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eliminar el cliente seleccionado con el menú abierto no rompe el modal', (tester) async {
    final shell = await pumpShell(tester);
    await abrirMenuClientes(tester);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    service.deleteCliente('c90000001');
    shell.goBranch(1);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Neida (c90000001)'), findsNothing);
    expect(find.text('Seleccioná un cliente'), findsOneWidget);
    expect(find.textContaining('Registrar Venta'), findsOneWidget);
  });

  testWidgets('el filtro de la lista cierra su menú cuando cambian los clientes', (tester) async {
    final shell = await pumpShell(tester);
    await tester.tap(find.text('Todos los clientes'));
    await tester.pumpAndSettle();
    expect(find.text('Zayda'), findsWidgets);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    service.deleteCliente('c90000003');
    shell.goBranch(1);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Zayda'), findsNothing);
  });

  testWidgets('eliminar un cliente con el menú abierto lo quita de las opciones', (tester) async {
    final shell = await pumpShell(tester);
    await abrirMenuClientes(tester);
    expect(find.text('Zayda (c90000003)'), findsWidgets);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    service.deleteCliente('c90000003');
    shell.goBranch(1);
    await tester.pumpAndSettle();

    expect(find.text('Zayda (c90000003)'), findsNothing);
    await tester.tap(find.text('Neida (c90000001)'));
    await tester.pumpAndSettle();
    expect(find.text('Neyza (c90000002)'), findsWidgets);
    expect(find.text('Zayda (c90000003)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
