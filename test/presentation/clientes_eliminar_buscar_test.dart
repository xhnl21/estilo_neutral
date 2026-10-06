import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/models/producto.dart';
import 'package:estilo_neutral/presentation/cubits/clientes/clientes_cubit.dart';
import 'package:estilo_neutral/presentation/pages/clientes_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

void main() {
  const org = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';
  late SheetsDataService service;

  Cliente cliente(String id, String nombre, {String tipo = 'V', String cedula = ''}) => Cliente(
        id: id,
        nombre: nombre,
        telefono: '',
        email: '',
        saldoDeudaUsd: 0,
        fechaRegistro: DateTime(2026, 10, 6),
        tipoDocumento: tipo,
        cedula: cedula,
      );

  setUp(() async {
    (service, _) = await servicioConServidor(inicializar: false);
    service.setCurrentOrganizacion(org);
    await service.addCliente(cliente('c90000001', 'Con Venta', cedula: '12345678'));
    await service.addCliente(cliente('c90000002', 'Sin Venta', tipo: 'J', cedula: '070133805'));
    await service.addProducto(const Producto(
      id: 'p90000001', cantidad: 5, nombre: 'Camisa', marca: 'M', modelo: 'X', talla: 'M', precioUsd: 10,
    ));
    await service.addVenta(
      clienteId: 'c90000001',
      items: const [(productoId: 'p90000001', cantidad: 1, precioUsd: 10)],
      metodoPagoId: service.metodosPagoActivos.first.id,
      abonoUsd: 0,
    );
  });

  test('no elimina un cliente con ventas y sí uno sin historial', () async {
    final cubit = ClientesCubit(dataService: service);

    expect(cubit.motivoNoEliminable('c90000001'), contains('1 venta'));
    cubit.deleteCliente('c90000001');
    expect(cubit.state.clientes.any((c) => c.id == 'c90000001'), isTrue);
    expect(cubit.state.actionSuccessMessage, isNull);

    expect(cubit.motivoNoEliminable('c90000002'), isNull);
    cubit.deleteCliente('c90000002');
    expect(cubit.state.clientes.any((c) => c.id == 'c90000002'), isFalse);
    await cubit.close();
  });

  test('la búsqueda encuentra por cédula y RIF en cualquier formato', () async {
    final cubit = ClientesCubit(dataService: service);

    for (final q in ['12345678', '12.345.678', 'V-12345678']) {
      cubit.search(q);
      expect(cubit.state.filteredClientes.map((c) => c.id), ['c90000001'], reason: q);
    }
    cubit.search('J-07013380-5');
    expect(cubit.state.filteredClientes.map((c) => c.id), ['c90000002']);
    // Un nombre no debe coincidir con cédulas por accidente.
    cubit.search('edymar');
    expect(cubit.state.filteredClientes, isEmpty);
    await cubit.close();
  });

  testWidgets('el formulario hace scroll en pantalla chica con teclado abierto', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 480 * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: ClientesPage(dataService: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo Cliente'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Registrar Nuevo Cliente'), findsOneWidget);
  });
}
