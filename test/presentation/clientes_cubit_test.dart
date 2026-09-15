import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/presentation/cubits/clientes/clientes_cubit.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

void main() {
  late SheetsDataService dataService;
  late ClientesCubit cubit;

  setUp(() {
    dataService = SheetsDataService();
    dataService.initialize();
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

  test('addCliente updates state and triggers success action message', () async {
    final newCliente = Cliente(
      id: 'c99990001',
      nombre: 'Nuevo Cliente Cubit',
      telefono: '+584129990001',
      email: 'cubit@test.com',
      saldoDeudaUsd: 0.0,
      fechaRegistro: DateTime(2026, 9, 15),
    );

    await cubit.addCliente(newCliente);

    expect(cubit.state.clientes.any((c) => c.id == 'c99990001'), isTrue);
    expect(cubit.state.actionSuccessMessage, isNotNull);
    expect(cubit.state.actionSuccessMessage, contains('Nuevo Cliente Cubit'));
  });

  test('deleteCliente removes client from list', () {
    final clienteToDelete = cubit.state.clientes.first;
    cubit.deleteCliente(clienteToDelete.id);

    expect(cubit.state.clientes.any((c) => c.id == clienteToDelete.id), isFalse);
    expect(cubit.state.actionSuccessMessage, contains('desincorporado'));
  });
}
