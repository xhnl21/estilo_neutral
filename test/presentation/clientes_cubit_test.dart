import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/presentation/cubits/clientes/clientes_cubit.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

void main() {
  late SheetsDataService dataService;
  late ClientesCubit cubit;

  setUp(() async {
    (dataService, _) = await servicioConServidor();
    cubit = ClientesCubit(dataService: dataService);
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has loaded clientes from dataService', () {
    expect(cubit.state.clientes.isNotEmpty, isTrue);
    expect(cubit.state.filteredClientes.length, equals(cubit.state.clientes.length));
  });

  test('search filters clientes by name, id or phone without setState', () {
    final primerCliente = cubit.state.clientes.first;
    cubit.search(primerCliente.nombre);

    expect(cubit.state.searchQuery, equals(primerCliente.nombre));
    expect(cubit.state.filteredClientes.any((c) => c.id == primerCliente.id), isTrue);

    // Searching non-existent query results in empty list
    cubit.search('NON_EXISTENT_QUERY_XYZ_123');
    expect(cubit.state.filteredClientes, isEmpty);
  });

  test('reacts to clientes added in dataService and exposes their resumen', () async {
    final newCliente = Cliente(
      id: 'c99990001',
      nombre: 'Nuevo Cliente Cubit',
      telefono: '+584129990001',
      email: 'cubit@test.com',
      saldoDeudaUsd: 0.0,
      fechaRegistro: DateTime(2026, 9, 15),
    );

    await dataService.addCliente(newCliente);

    // El ID lo asigna el servidor (R1), no el que traía el objeto.
    final creado = cubit.state.clientes.firstWhere((c) => c.nombre == 'Nuevo Cliente Cubit');
    expect(creado.id, isNot('c99990001'));
    expect(cubit.state.resumenes.containsKey(creado.id), isTrue);
    expect(cubit.state.resumenDe(creado.id).hasDebt, isFalse);
  });

  test('deleteCliente removes client from list', () async {
    // Un cliente sin ventas ni créditos: los que tienen historial no se
    // pueden eliminar (ver motivoNoEliminableCliente).
    final clienteToDelete = Cliente(
      id: 'c99990002',
      nombre: 'Sin Historial',
      telefono: '',
      email: '',
      saldoDeudaUsd: 0.0,
      fechaRegistro: DateTime(2026, 9, 15),
    );
    await dataService.addCliente(clienteToDelete);
    final id = dataService.clientes.firstWhere((c) => c.nombre == 'Sin Historial').id;
    await cubit.deleteCliente(id);

    expect(cubit.state.clientes.any((c) => c.id == id), isFalse);
    expect(cubit.state.actionSuccessMessage, contains('desincorporado'));
  });
}
