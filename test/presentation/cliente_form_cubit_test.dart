import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/presentation/cubits/cliente_form/cliente_form_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/cliente_form/cliente_form_state.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

void main() {
  // Organización distinta a la por defecto del modelo Cliente, para detectar
  // ediciones que pierdan el organizacionId.
  const org = 'org-test-cliente-form';
  late SheetsDataService service;
  late ServidorSimulado servidor;

  setUp(() async {
    (service, servidor) = await servicioConServidor(inicializar: false);
    service.setCurrentOrganizacion(org);
  });

  Future<Cliente> seedCliente({String cedula = '12345678'}) async {
    await service.addCliente(Cliente(
      id: service.nextClienteId,
      nombre: 'Cliente Existente',
      telefono: '04141234567',
      email: 'existente@test.com',
      saldoDeudaUsd: 42.5,
      fechaRegistro: DateTime(2026, 1, 10),
      tipoDocumento: 'V',
      cedula: cedula,
    ));
    return service.clientes.last;
  }

  test('separa código y número aunque Sheets haya quitado el 0 inicial', () {
    final cubit = ClienteFormCubit(
      dataService: service,
      cliente: Cliente(
        id: 'c00000005',
        nombre: 'Edymar',
        telefono: '4124054635',
        email: '',
        saldoDeudaUsd: 0,
        fechaRegistro: DateTime(2026, 1, 1),
      ),
    );

    expect(cubit.state.codigoTelefono, '0412');
    expect(cubit.state.telefonoNumeroInicial, '4054635');
    cubit.close();
  });

  test('un código desactivado del cliente se ofrece como opción seleccionada', () {
    final cubit = ClienteFormCubit(
      dataService: service,
      cliente: Cliente(
        id: 'c00000006',
        nombre: 'Código viejo',
        telefono: '+584199999999',
        email: '',
        saldoDeudaUsd: 0,
        fechaRegistro: DateTime(2026, 1, 1),
      ),
    );

    expect(cubit.state.codigoTelefono, '0419');
    expect(cubit.state.codigosTelefono, contains('0419'));
    expect(cubit.state.telefonoNumeroInicial, '9999999');
    cubit.close();
  });

  test('acepta RIF con guiones y lo guarda normalizado', () async {
    final cubit = ClienteFormCubit(dataService: service);
    cubit.tipoDocumentoChanged('J');

    await cubit.submit(
      nombre: 'Banesco',
      cedula: '07013380-5',
      telefonoNumero: '',
      email: '',
    );

    expect(cubit.state.errors, isEmpty);
    final guardado = service.clientes.firstWhere((c) => c.nombre == 'Banesco');
    expect(guardado.cedula, '070133805');
    expect(guardado.documentoCompleto, 'J-07013380-5');
    await cubit.close();
  });

  test('rechaza RIF con dígito verificador inválido', () async {
    final cubit = ClienteFormCubit(dataService: service);
    cubit.tipoDocumentoChanged('J');

    await cubit.submit(nombre: 'Empresa', cedula: '07013380-6', telefonoNumero: '', email: '');

    expect(cubit.state.errors[ClienteFormField.cedula], contains('verificador'));
    await cubit.close();
  });

  test('un tipo de documento desactivado del cliente se conserva', () {
    final cubit = ClienteFormCubit(
      dataService: service,
      cliente: Cliente(
        id: 'c00000007',
        nombre: 'Pasaporte',
        telefono: '',
        email: '',
        saldoDeudaUsd: 0,
        fechaRegistro: DateTime(2026, 1, 1),
        tipoDocumento: 'P',
        cedula: 'AB123456',
      ),
    );

    expect(cubit.state.tipoDocumento, 'P');
    expect(cubit.state.tiposDocumento, contains('P'));
    cubit.close();
  });

  test('rechaza campos inválidos sin guardar', () async {
    final cubit = ClienteFormCubit(dataService: service);
    final antes = service.clientes.length;

    await cubit.submit(
      nombre: ' ',
      cedula: '12ab',
      telefonoNumero: '123',
      email: 'no-es-correo',
      deuda: '-5',
    );

    expect(cubit.state.errors.keys, containsAll(ClienteFormField.values));
    expect(cubit.state.status, ClienteFormStatus.initial);
    expect(service.clientes.length, antes);
    await cubit.close();
  });

  test('rechaza una cédula duplicada en la organización', () async {
    final existente = await seedCliente();
    final cubit = ClienteFormCubit(dataService: service);

    await cubit.submit(
      nombre: 'Otro Cliente',
      cedula: existente.cedula,
      telefonoNumero: '',
      email: '',
    );

    expect(cubit.state.errors[ClienteFormField.cedula], contains(existente.id));
    await cubit.close();
  });

  test('fieldChanged limpia solo el error del campo editado', () async {
    final cubit = ClienteFormCubit(dataService: service);
    await cubit.submit(nombre: '', cedula: '', telefonoNumero: '', email: 'x');

    cubit.fieldChanged(ClienteFormField.nombre);

    expect(cubit.state.errors.containsKey(ClienteFormField.nombre), isFalse);
    expect(cubit.state.errors.containsKey(ClienteFormField.email), isTrue);
    await cubit.close();
  });

  test('alta rechazada por Sheets: no queda guardada y el formulario sigue abierto', () async {
    final cubit = ClienteFormCubit(dataService: service);
    servidor.rechazar();

    await cubit.submit(nombre: 'Rechazado', cedula: '', telefonoNumero: '', email: '');

    expect(cubit.state.status, ClienteFormStatus.failure);
    expect(cubit.state.resultType, ClienteFormResultType.error);
    expect(service.clientes.any((c) => c.nombre == 'Rechazado'), isFalse);
    await cubit.close();
  });

  test('alta confirmada: normaliza los datos y usa la organización actual', () async {
    final cubit = ClienteFormCubit(dataService: service);

    await cubit.submit(
      nombre: 'Nuevo Cliente',
      cedula: '87.654.321',
      telefonoNumero: '7654321',
      email: 'Nuevo@Test.com',
      deuda: '10,50',
    );

    expect(cubit.state.status, ClienteFormStatus.success);
    expect(cubit.state.resultType, ClienteFormResultType.success);
    final guardado = service.clientes.firstWhere((c) => c.nombre == 'Nuevo Cliente');
    expect(guardado.cedula, '87654321');
    expect(guardado.email, 'nuevo@test.com');
    expect(guardado.saldoDeudaUsd, 10.5);
    expect(guardado.organizacionId, org);
    await cubit.close();
  });

  test('edición conserva organización, fecha de registro y saldo de deuda', () async {
    final original = await seedCliente();
    final cubit = ClienteFormCubit(dataService: service, cliente: original);

    expect(cubit.state.codigoTelefono, '0414');
    expect(cubit.state.telefonoNumeroInicial, '1234567');

    await cubit.submit(
      nombre: 'Nombre Editado',
      cedula: original.cedula,
      telefonoNumero: '7654321',
      email: original.email,
    );

    expect(cubit.state.status, ClienteFormStatus.success);
    final editado = service.clientes.firstWhere((c) => c.id == original.id);
    expect(editado.nombre, 'Nombre Editado');
    expect(editado.telefono, '+584147654321');
    expect(editado.organizacionId, org);
    expect(editado.fechaRegistro, original.fechaRegistro);
    expect(editado.saldoDeudaUsd, original.saldoDeudaUsd);
    await cubit.close();
  });
}
