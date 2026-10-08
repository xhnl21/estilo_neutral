import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/features/notificaciones/notificaciones.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/models/organizacion.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../../test_servidor.dart';

Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 10));

Cliente _cliente(String nombre, String email) => Cliente(
      id: '',
      nombre: nombre,
      telefono: '',
      email: email,
      saldoDeudaUsd: 0,
      fechaRegistro: DateTime(2026, 10, 8),
    );

/// Organización actual con correo, dos clientes con correo y uno sin, y una
/// notificación guardada.
Future<(SheetsDataService, ServidorSimulado, String)> _escenario({bool conCorreo = true}) async {
  final (ds, servidor) = await servicioConServidor();
  // Organización nueva (sin los clientes de los datos de respaldo).
  await ds.addOrganizacion('Tienda Correo', email: conCorreo ? 'Ventas@Tienda.com' : '');
  ds.setCurrentOrganizacion(ds.organizaciones.firstWhere((o) => o.nombre == 'Tienda Correo').id);
  await ds.addCliente(_cliente('Ana', 'ana@x.com'));
  await ds.addCliente(_cliente('Beto', 'beto@x.com'));
  await ds.addCliente(_cliente('Sin correo', ''));
  final tipo = await ds.addTipoNotificacion('Pago quincenal');
  final p = await ds.addPlantillaNotificacion(tipoId: tipo.id, titulo: 'Día de pago', cuerpo: 'Hoy se pagó la quincena.');
  return (ds, servidor, p.id);
}

void main() {
  group('Organización con correo', () {
    test('guarda el correo normalizado; vacío está permitido; inválido se rechaza', () async {
      final (ds, servidor) = await servicioConServidor();
      final org = ds.organizaciones.firstWhere((o) => o.id == organizacionDePrueba);
      await ds.updateOrganizacion(Organizacion(id: org.id, nombre: org.nombre, email: ' Ventas@Tienda.com '));
      expect(servidor.enviados.last['data'], containsPair('email', 'ventas@tienda.com'));
      expect(ds.organizaciones.firstWhere((o) => o.id == org.id).tieneEmail, isTrue);
      await expectLater(
          ds.updateOrganizacion(Organizacion(id: org.id, nombre: org.nombre, email: 'no-es-correo')), throwsA(isA<ArgumentError>()));
      await ds.addOrganizacion('Norte', email: 'norte@tienda.com');
      expect(servidor.enviados.last['data'], containsPair('email', 'norte@tienda.com'));
      expect(Organizacion.fromRow(const ['o1', 'X']).email, '');
    });
  });

  group('SheetsDataService', () {
    test('clientesConEmail: activos de la organización con correo válido', () async {
      final (ds, _, _) = await _escenario();
      expect(ds.clientesConEmail.map((c) => c.nombre), unorderedEquals(['Ana', 'Beto']));
    });

    test('enviarCorreoClientes manda asunto, mensaje y destinatarios', () async {
      final (ds, servidor, _) = await _escenario();
      final ids = {ds.clientesConEmail.first.id};
      servidor.respuesta = jsonEncode({'status': 'success', 'id': 'co00000001', 'enviados': 1, 'fallidos': 0, 'restantes': 99});
      final r = await ds.enviarCorreoClientes(asunto: 'Día de pago', cuerpo: 'Texto', clienteIds: ids);
      final envio = servidor.enviados.last;
      expect(envio['action'], 'enviar_correo');
      expect(envio['data'], {'asunto': 'Día de pago', 'cuerpo': 'Texto', 'todos': false, 'cliente_ids': ids.toList()});
      expect((r.enviados, r.restantes), (1, 99));
      await expectLater(ds.enviarCorreoClientes(asunto: 'A', cuerpo: 'B'), throwsA(isA<ArgumentError>()), reason: 'sin clientes');
    });

    test('un rechazo del servidor (p. ej. sin cupo) llega como StateError con su motivo', () async {
      final (ds, servidor, _) = await _escenario();
      servidor.respuesta = jsonEncode({'status': 'error', 'code': 'cupo_correo', 'message': 'Google permite enviar 0 correos más hoy.'});
      await expectLater(ds.enviarCorreoClientes(asunto: 'A', cuerpo: 'B', todos: true),
          throwsA(isA<StateError>().having((e) => e.message, 'msg', contains('0 correos'))));
    });
  });

  group('EnviarCorreoCubit', () {
    test('todos / elegidos, cupo y envío con la notificación guardada', () async {
      final (ds, servidor, plantillaId) = await _escenario();
      servidor.respuesta = jsonEncode({'status': 'success', 'restantes': 1});
      final cubit = EnviarCorreoCubit(dataService: ds, plantillaId: plantillaId);
      await _esperar();
      expect(cubit.state.organizacion?.email, 'ventas@tienda.com');
      expect((cubit.state.clientes.length, cubit.state.sinCorreo), (2, 1));
      expect(cubit.state.cupoRestante, 1);
      expect(cubit.state.puedeEnviar, isFalse, reason: 'dos destinatarios y cupo de uno');
      cubit.alternarCliente(cubit.state.clientes.first.id);
      expect((cubit.state.todos, cubit.state.cantidadDestinatarios, cubit.state.puedeEnviar), (false, 1, true));
      cubit.buscar('BETO');
      expect(cubit.state.clientesFiltrados.single.nombre, 'Beto');

      servidor.respuesta = jsonEncode({'status': 'success', 'id': 'co1', 'enviados': 1, 'fallidos': 0, 'restantes': 0});
      await cubit.enviar();
      final envio = servidor.enviados.lastWhere((e) => e['action'] == 'enviar_correo');
      expect(envio['data'], containsPair('asunto', 'Día de pago'));
      expect(envio['data'], containsPair('cuerpo', 'Hoy se pagó la quincena.'));
      expect(cubit.state.mensaje, 'Correo enviado a 1 cliente.');
      expect(cubit.state.cupoRestante, 0);
      await cubit.close();
    });

    test('sin correo en la organización no se puede enviar', () async {
      final (ds, _, plantillaId) = await _escenario(conCorreo: false);
      final cubit = EnviarCorreoCubit(dataService: ds, plantillaId: plantillaId);
      await _esperar();
      expect(cubit.state.organizacionSinCorreo, isTrue);
      expect(cubit.state.puedeEnviar, isFalse);
      await cubit.close();
    });

    test('si el servidor rechaza, muestra su motivo', () async {
      final (ds, servidor, plantillaId) = await _escenario();
      final cubit = EnviarCorreoCubit(dataService: ds, plantillaId: plantillaId);
      await _esperar();
      servidor.respuesta = jsonEncode({'status': 'error', 'message': 'Google permite enviar 1 correo más hoy y elegiste 2.'});
      await cubit.enviar();
      expect(cubit.state.status, EnviarCorreoStatus.error);
      expect(cubit.state.mensaje, contains('elegiste 2'));
      await cubit.close();
    });
  });

  testWidgets('Ver: el canal "Correo a clientes" muestra remitente, destinatarios y envío', (tester) async {
    tester.view.physicalSize = const Size(392 * 2.8, 800 * 2.8);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    late SheetsDataService ds;
    late String plantillaId;
    await tester.runAsync(() async {
      final (d, _, p) = await _escenario();
      ds = d;
      plantillaId = p;
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: EnviarNotificacionPage(dataService: ds, plantillaId: plantillaId),
    ));
    await tester.pump();
    await tester.tap(find.text('Correo a clientes'));
    await tester.pump();
    expect(find.text('Responder a: ventas@tienda.com'), findsOneWidget);
    expect(find.text('Todos (2)'), findsOneWidget);
    expect(find.textContaining('1 cliente no tiene correo'), findsOneWidget);
    await tester.tap(find.text('Elegir'));
    await tester.pump();
    expect(find.text('ana@x.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Las consultas de cupo arrancaron en el reloj simulado: se deja vencer
    // su timeout de red para que no queden temporizadores pendientes.
    await tester.pump(const Duration(seconds: 30));
  });
}
