import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/models/producto.dart';
import 'package:estilo_neutral/presentation/cubits/nueva_venta/nueva_venta_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/nueva_venta/nueva_venta_state.dart';
import 'package:estilo_neutral/presentation/cubits/ventas/ventas_cubit.dart';
import 'package:estilo_neutral/presentation/pages/ventas_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

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
    // Servidor simulado que confirma: sin él las altas se revierten (R4).
    (service, _) = await servicioConServidor(inicializar: false);
    service.setCurrentOrganizacion(org);
    await service.addCliente(cliente('c90000001', 'Cliente Inicial'));
    await service.addProducto(const Producto(
      id: 'p90000001',
      cantidad: 5,
      nombre: 'Camisa Test',
      marca: 'M',
      modelo: 'X',
      talla: 'M',
      precioUsd: 10,
    ));
  });

  test('un cliente creado con el formulario abierto aparece sin refrescar', () async {
    final cubit = NuevaVentaCubit(dataService: service, initialClienteId: 'c90000001');

    await service.addCliente(cliente('c90000002', 'Cliente Nuevo'));

    expect(cubit.state.clientes.map((c) => c.id), contains('c90000002'));
    expect(cubit.state.selectedClienteId, 'c90000001');
    await cubit.close();
  });

  test('si el cliente seleccionado desaparece, la selección queda vacía', () async {
    final cubit = NuevaVentaCubit(dataService: service, initialClienteId: 'c90000001');

    service.deleteCliente('c90000001');

    expect(cubit.state.selectedClienteId, isNull);
    await cubit.submit('0');
    expect(cubit.state.message, contains('Seleccioná un cliente'));
    expect(cubit.state.status, NuevaVentaStatus.initial);
    await cubit.close();
  });

  test('addToCart rechaza más unidades que el stock', () async {
    final cubit = NuevaVentaCubit(dataService: service, initialClienteId: 'c90000001');

    expect(cubit.addToCart('6'), isFalse);
    expect(cubit.state.messageType, NuevaVentaMessageType.error);
    expect(cubit.addToCart('2'), isTrue);
    expect(cubit.state.totalCarrito, 20);
    await cubit.close();
  });

  test('VentasCubit quita el filtro cuando se elimina el cliente filtrado', () async {
    final cubit = VentasCubit(dataService: service, initialClienteId: 'c90000001');
    await service.addCliente(cliente('c90000005', 'Otro'));
    expect(cubit.state.filtroClienteId, 'c90000001');

    service.deleteCliente('c90000001');

    expect(cubit.state.filtroClienteId, isNull);
    expect(cubit.state.filteredVentas.length, cubit.state.ventas.length);
    await cubit.close();
  });

  testWidgets('el dropdown del modal abierto muestra el cliente recién creado', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: VentasPage(dataService: service),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva Venta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Registrar Venta'), findsOneWidget);

    await tester.runAsync(() => service.addCliente(cliente('c90000002', 'Creado Con Modal Abierto')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cliente Inicial (c90000001)'));
    await tester.pumpAndSettle();

    expect(find.text('Creado Con Modal Abierto (c90000002)'), findsWidgets);
  });

  testWidgets('editar y eliminar clientes actualiza el select del modal abierto', (tester) async {
    await tester.runAsync(() => service.addCliente(cliente('c90000002', 'Para Eliminar')));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: VentasPage(dataService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva Venta'));
    await tester.pumpAndSettle();

    // Editar el cliente seleccionado: el texto mostrado cambia sin reabrir.
    final original = service.clientes.firstWhere((c) => c.id == 'c90000001');
    await tester.runAsync(() => service.updateCliente(original.copyWith(nombre: 'Nombre Editado')));
    await tester.pumpAndSettle();
    expect(find.text('Nombre Editado (c90000001)'), findsOneWidget);
    expect(find.text('Cliente Inicial (c90000001)'), findsNothing);

    // Eliminar otro cliente: desaparece de las opciones.
    service.deleteCliente('c90000002');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nombre Editado (c90000001)'));
    await tester.pumpAndSettle();
    expect(find.text('Para Eliminar (c90000002)'), findsNothing);
    await tester.tap(find.text('Nombre Editado (c90000001)').last);
    await tester.pumpAndSettle();

    // Eliminar el cliente seleccionado: el select queda vacío pidiendo elegir.
    service.deleteCliente('c90000001');
    await tester.pumpAndSettle();
    expect(find.text('Nombre Editado (c90000001)'), findsNothing);
    expect(find.text('Seleccioná un cliente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eliminar el cliente filtrado en la lista de ventas quita el filtro', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: VentasPage(dataService: service, clienteIdInicial: 'c90000001'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cliente Inicial'), findsOneWidget);

    service.deleteCliente('c90000001');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cliente Inicial'), findsNothing);
    expect(find.text('Todos los clientes'), findsOneWidget);
  });
}
