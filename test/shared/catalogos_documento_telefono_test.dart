import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/presentation/cubits/codigos_telefono/codigos_telefono_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/tipos_documento/tipos_documento_cubit.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import 'package:dio/dio.dart';
import '../test_fake_dio.dart';
import '../test_sheets_config.dart';

/// Servicio cuyo Apps Script responde siempre [respuesta] (sin red).
SheetsDataService servicioConServidor(String respuesta, {List<Map<String, dynamic>>? enviados}) {
  final dio = Dio()
    ..httpClientAdapter = FakeHttpClientAdapter(
      statusCode: 200,
      responseBody: respuesta,
      onRequest: (o) {
        if (o.data is String && enviados != null) enviados.add(jsonDecode(o.data as String) as Map<String, dynamic>);
        if (o.data is Map && enviados != null) enviados.add(Map<String, dynamic>.from(o.data as Map));
      },
    );
  return SheetsDataService(spreadsheetId: testSpreadsheetId, appsScriptUrl: testAppsScriptUrl, dio: dio);
}

void main() {
  group('CodigoTelefono Model Tests', () {
    test('Parsea correctamente desde una fila de Google Sheets', () {
      final row = ['ct00000001', '0414', 'TRUE'];
      final ct = CodigoTelefono.fromRow(row);

      expect(ct.id, 'ct00000001');
      expect(ct.codigo, '0414');
      expect(ct.status, isTrue);
    });

    test('Parsea status inactivo y serializa toMap', () {
      final row = ['ct00000002', '0424', 'false'];
      final ct = CodigoTelefono.fromRow(row);

      expect(ct.status, isFalse);
      final map = ct.toMap();
      expect(map['codigo'], '0424');
      expect(map['status'], isFalse);
    });

    test('copyWith genera una nueva instancia modificada', () {
      const ct = CodigoTelefono(id: 'ct00000001', codigo: '0414', status: true);
      final modified = ct.copyWith(codigo: '0412', status: false);

      expect(modified.id, 'ct00000001');
      expect(modified.codigo, '0412');
      expect(modified.status, isFalse);
    });
  });

  group('CodigoTelefono: códigos que Google Sheets guardó como número', () {
    test('restaura el 0 inicial al leer', () {
      expect(CodigoTelefono.fromRow(['ct1', '414', 'TRUE']).codigo, '0414');
      expect(CodigoTelefono.fromRow(['ct1', '414.0', 'TRUE']).codigo, '0414');
      expect(CodigoTelefono.fromRow(['ct1', '212', 'TRUE']).codigo, '0212');
      expect(CodigoTelefono.fromRow(['ct1', '0414', 'TRUE']).codigo, '0414');
    });

    test('un código normalizado sirve para armar el E.164 del cliente', () {
      final codigo = CodigoTelefono.fromRow(['ct1', '414', 'TRUE']).codigo;
      expect(TelefonoVe(codigo: codigo, numero: '1234567').e164, '+584141234567');
    });
  });

  group('Catálogos sin conexión: el cambio se revierte y se informa el error', () {
    late SheetsDataService ds;

    setUp(() {
      // Sin URL de Apps Script la sincronización falla siempre.
      ds = SheetsDataService(spreadsheetId: testSpreadsheetId, appsScriptUrl: '');
    });

    test('crear código', () async {
      await expectLater(ds.addCodigoTelefono(codigo: '0212'), throwsA(isA<StateError>()));
      expect(ds.codigosTelefono.any((c) => c.codigo == '0212'), isFalse);
    });

    test('editar código', () async {
      final item = ds.codigosTelefono.firstWhere((c) => c.codigo == '0414');
      await expectLater(
        ds.updateCodigoTelefono(id: item.id, nuevoCodigo: '0415'),
        throwsA(isA<StateError>()),
      );
      expect(ds.codigosTelefono.firstWhere((c) => c.id == item.id).codigo, '0414');
    });

    test('activar/desactivar código', () async {
      final item = ds.codigosTelefono.firstWhere((c) => c.codigo == '0422');
      await expectLater(ds.toggleCodigoTelefonoStatus(item.id), throwsA(isA<StateError>()));
      expect(ds.codigosTelefono.firstWhere((c) => c.id == item.id).status, isTrue);
    });

    test('eliminar código', () async {
      final item = ds.codigosTelefono.firstWhere((c) => c.codigo == '0422');
      final antes = ds.codigosTelefono.map((c) => c.id).toList();
      await expectLater(ds.deleteCodigoTelefono(item.id), throwsA(isA<StateError>()));
      expect(ds.codigosTelefono.map((c) => c.id).toList(), antes);
    });

    test('editar y desactivar tipo de documento', () async {
      final item = ds.tiposDocumento.firstWhere((t) => t.tipo == 'G');
      await expectLater(
        ds.updateTipoDocumento(id: item.id, nuevoTipo: 'G', nuevaDescripcion: 'Otro'),
        throwsA(isA<StateError>()),
      );
      await expectLater(ds.toggleTipoDocumentoStatus(item.id), throwsA(isA<StateError>()));
      final despues = ds.tiposDocumento.firstWhere((t) => t.id == item.id);
      expect(despues.descripcion, item.descripcion);
      expect(despues.status, isTrue);
    });

    test('el formato del código se valida antes de enviar', () async {
      await expectLater(ds.addCodigoTelefono(codigo: '414'), throwsA(isA<ArgumentError>()));
      await expectLater(ds.addCodigoTelefono(codigo: '04141'), throwsA(isA<ArgumentError>()));
    });

    test('el Cubit muestra el error sin prefijos técnicos', () async {
      final cubit = CodigosTelefonoCubit(dataService: ds);
      final errores = <String>[];
      final sub = cubit.stream.listen((st) {
        if (st.errorMessage != null) errores.add(st.errorMessage!);
      });
      await expectLater(cubit.addCodigoTelefono('0212'), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      expect(errores, contains(startsWith('No se pudo guardar en Google Sheets')));
      await sub.cancel();
      await cubit.close();
    });

    test('una respuesta {status: "error"} del script también revierte', () async {
      final conError = servicioConServidor('{"status":"error","message":"Registro no encontrado"}');
      final item = conError.codigosTelefono.firstWhere((c) => c.codigo == '0422');
      await expectLater(conError.toggleCodigoTelefonoStatus(item.id), throwsA(isA<StateError>()));
      expect(conError.codigosTelefono.firstWhere((c) => c.id == item.id).status, isTrue);
    });

    test('lo que se envía al script incluye el código y el status', () async {
      final enviados = <Map<String, dynamic>>[];
      final ok = servicioConServidor('{"status":"success"}', enviados: enviados);
      final item = ok.codigosTelefono.firstWhere((c) => c.codigo == '0422');
      await ok.updateCodigoTelefono(id: item.id, nuevoCodigo: '0418');
      await ok.toggleCodigoTelefonoStatus(item.id);
      expect(enviados.map((e) => e['data']), containsAllInOrder([
        {'codigo': '0418'},
        {'status': false},
      ]));
    });
  });

  group('TipoDocumento Model Tests', () {
    test('Parsea correctamente desde una fila de Google Sheets', () {
      final row = ['td00000001', 'V', 'Venezolano', 'TRUE'];
      final td = TipoDocumento.fromRow(row);

      expect(td.id, 'td00000001');
      expect(td.tipo, 'V');
      expect(td.descripcion, 'Venezolano');
      expect(td.status, isTrue);
    });

    test('copyWith y toMap serializan fielmente', () {
      const td = TipoDocumento(id: 'td00000002', tipo: 'E', descripcion: 'Extranjero', status: true);
      final modified = td.copyWith(descripcion: 'Residente Extranjero', status: false);

      expect(modified.descripcion, 'Residente Extranjero');
      expect(modified.status, isFalse);
      expect(modified.toMap()['tipo'], 'E');
    });
  });

  group('SheetsDataService - CRUD Códigos de Teléfono', () {
    late SheetsDataService ds;

    setUp(() {
      ds = servicioConServidor('{"status":"success"}');
    });

    test('Inicializa con catálogo por defecto', () {
      expect(ds.codigosTelefono.length, greaterThanOrEqualTo(6));
      expect(ds.codigosTelefonoActivos, containsAll(['0414', '0424', '0416', '0426', '0412', '0422']));
    });

    test('addCodigoTelefono agrega y valida duplicados y vacíos', () async {
      await ds.addCodigoTelefono(codigo: '0212');
      expect(ds.codigosTelefono.any((c) => c.codigo == '0212'), isTrue);

      expect(() => ds.addCodigoTelefono(codigo: '0212'), throwsA(isA<ArgumentError>()));
      expect(() => ds.addCodigoTelefono(codigo: '   '), throwsA(isA<ArgumentError>()));
    });

    test('updateCodigoTelefono actualiza código existente', () async {
      final item = ds.codigosTelefono.first;
      final ok = await ds.updateCodigoTelefono(id: item.id, nuevoCodigo: '0415');
      expect(ok, isTrue);
      expect(ds.codigosTelefono.firstWhere((c) => c.id == item.id).codigo, '0415');
    });

    test('toggleCodigoTelefonoStatus desactiva y activa', () async {
      final item = ds.codigosTelefono.firstWhere((c) => c.codigo == '0422');
      final ok = await ds.toggleCodigoTelefonoStatus(item.id);
      expect(ok, isTrue);
      expect(ds.codigosTelefono.firstWhere((c) => c.id == item.id).status, isFalse);
    });

    test('deleteCodigoTelefono elimina registro si no está en uso', () async {
      await ds.addCodigoTelefono(codigo: '0999');
      final creado = ds.codigosTelefono.firstWhere((c) => c.codigo == '0999');
      final ok = await ds.deleteCodigoTelefono(creado.id);
      expect(ok, isTrue);
      expect(ds.codigosTelefono.any((c) => c.codigo == '0999'), isFalse);
    });
  });

  group('SheetsDataService - CRUD Tipos de Documento', () {
    late SheetsDataService ds;

    setUp(() {
      ds = servicioConServidor('{"status":"success"}');
    });

    test('Inicializa con catálogo por defecto', () {
      expect(ds.tiposDocumento.length, greaterThanOrEqualTo(4));
      expect(ds.tiposDocumentoActivos, containsAll(['V', 'E', 'J', 'G']));
    });

    test('addTipoDocumento agrega y valida duplicados y vacíos', () async {
      await ds.addTipoDocumento(tipo: 'P', descripcion: 'Pasaporte');
      expect(ds.tiposDocumento.any((t) => t.tipo == 'P'), isTrue);

      expect(() => ds.addTipoDocumento(tipo: 'P', descripcion: 'Duplicado'), throwsA(isA<ArgumentError>()));
      expect(() => ds.addTipoDocumento(tipo: '', descripcion: 'Vacío'), throwsA(isA<ArgumentError>()));
    });

    test('updateTipoDocumento actualiza registro', () async {
      await ds.addTipoDocumento(tipo: 'C', descripcion: 'Comunal');
      final item = ds.tiposDocumento.firstWhere((t) => t.tipo == 'C');
      final ok = await ds.updateTipoDocumento(id: item.id, nuevoTipo: 'C', nuevaDescripcion: 'Consejo Comunal');
      expect(ok, isTrue);
      expect(ds.tiposDocumento.firstWhere((t) => t.id == item.id).descripcion, 'Consejo Comunal');
    });

    test('toggleTipoDocumentoStatus alterna estado', () async {
      await ds.addTipoDocumento(tipo: 'M', descripcion: 'Militar');
      final item = ds.tiposDocumento.firstWhere((t) => t.tipo == 'M');
      final ok = await ds.toggleTipoDocumentoStatus(item.id);
      expect(ok, isTrue);
      expect(ds.tiposDocumento.firstWhere((t) => t.id == item.id).status, isFalse);
    });

    test('deleteTipoDocumento elimina registro', () async {
      await ds.addTipoDocumento(tipo: 'X', descripcion: 'Temporal');
      final item = ds.tiposDocumento.firstWhere((t) => t.tipo == 'X');
      final ok = await ds.deleteTipoDocumento(item.id);
      expect(ok, isTrue);
      expect(ds.tiposDocumento.any((t) => t.tipo == 'X'), isFalse);
    });
  });

  group('Cubits Tests', () {
    late SheetsDataService ds;

    setUp(() {
      ds = SheetsDataService(spreadsheetId: testSpreadsheetId, appsScriptUrl: testAppsScriptUrl);
    });

    test('CodigosTelefonoCubit filtra por búsqueda y reacciona a cambios', () {
      final cubit = CodigosTelefonoCubit(dataService: ds);
      expect(cubit.state.codigos.isNotEmpty, isTrue);

      cubit.search('0414');
      expect(cubit.state.filteredCodigos.length, 1);
      expect(cubit.state.filteredCodigos.first.codigo, '0414');

      cubit.close();
    });

    test('TiposDocumentoCubit filtra por búsqueda y reacciona a cambios', () {
      final cubit = TiposDocumentoCubit(dataService: ds);
      expect(cubit.state.tipos.isNotEmpty, isTrue);

      cubit.search('Venezolano');
      expect(cubit.state.filteredTipos.length, 1);
      expect(cubit.state.filteredTipos.first.tipo, 'V');

      cubit.close();
    });
  });
}
