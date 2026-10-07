import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/models/fila_hoja.dart';
import 'package:estilo_neutral/models/usuario.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

void main() {
  group('estadoActivo', () {
    test('vacío o desconocido cuenta como activo (filas anteriores a la columna)', () {
      for (final v in [null, '', 'activo', 'TRUE', true, 1]) {
        expect(estadoActivo(v), isTrue, reason: '$v');
      }
    });
    test('inactivo, false, 0 o no', () {
      for (final v in ['inactivo', 'Inactivo ', 'false', false, 0, '0', 'no']) {
        expect(estadoActivo(v), isFalse, reason: '$v');
      }
    });
    test('Usuario lee la columna F y Cliente la J', () {
      expect(Usuario.fromRow(['u1', 'a@x.com', 'A', 'V', '1', 'inactivo']).activo, isFalse);
      expect(Usuario.fromRow(['u1', 'a@x.com', 'A', 'V', '1']).activo, isTrue);
      final fila = ['c1', 'Ana', '', '', 0, '2026-01-01', 'org', 'V', '1', 'inactivo'];
      expect(Cliente.fromRow(fila).activo, isFalse);
      expect(Cliente.fromRow(fila.sublist(0, 9)).activo, isTrue);
      expect(Cliente.fromRow(fila).toMap()['status'], isFalse);
    });
  });

  group('SheetsDataService', () {
    late SheetsDataService ds;
    late ServidorSimulado servidor;

    setUp(() async => (ds, servidor) = await servicioConServidor());

    test('inactivar un cliente: solo envía el status, lo saca de ventas nuevas y no lo borra', () async {
      final cliente = ds.clientes.first;
      await ds.cambiarEstadoCliente(cliente.id, activo: false);
      expect(servidor.enviados.last, containsPair('data', {'status': false}));
      expect(servidor.enviados.last['id'], cliente.id);
      expect(ds.clientes.any((c) => c.id == cliente.id && !c.activo), isTrue);
      expect(ds.clientesActivos.any((c) => c.id == cliente.id), isFalse);

      // Editar sus datos no lo reactiva.
      await ds.updateCliente(ds.clientes.firstWhere((c) => c.id == cliente.id).copyWith(nombre: 'Otro', activo: true));
      expect(ds.clientes.firstWhere((c) => c.id == cliente.id).activo, isFalse);

      await ds.cambiarEstadoCliente(cliente.id, activo: true);
      expect(ds.clientesActivos.any((c) => c.id == cliente.id), isTrue);
    });

    test('si Sheets rechaza el cambio de estado, se revierte', () async {
      final cliente = ds.clientes.first;
      servidor.rechazar('sin red');
      await expectLater(ds.cambiarEstadoCliente(cliente.id, activo: false), throwsA(isA<StateError>()));
      expect(ds.clientes.firstWhere((c) => c.id == cliente.id).activo, isTrue);
    });

    test('usuario: nadie se inactiva a sí mismo; a otro sí, y pierde el acceso', () async {
      final yo = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      final otro = ds.usuarios.firstWhere((u) => u.email != 'xhnl21@gmail.com');
      expect(ds.motivoNoInactivable(yo), isNotNull);
      await expectLater(ds.cambiarEstadoUsuario(yo.id, activo: false), throwsA(isA<ArgumentError>()));
      expect(ds.usuarios.firstWhere((u) => u.id == yo.id).activo, isTrue);

      await ds.cambiarEstadoUsuario(otro.id, activo: false);
      expect(servidor.enviados.last, containsPair('data', {'status': false}));
      expect(ds.resolverAcceso(otro.email).motivo, contains('está inactiva'));

      // Editarlo no lo reactiva.
      await ds.updateUsuario(ds.usuarios.firstWhere((u) => u.id == otro.id).copyWith(nombre: 'X', activo: true),
          organizacionId: organizacionDePrueba);
      expect(ds.usuarios.firstWhere((u) => u.id == otro.id).activo, isFalse);
    });
  });
}
