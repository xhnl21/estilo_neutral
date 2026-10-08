import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/features/notificaciones/notificaciones.dart';
import 'package:estilo_neutral/models/plantilla_notificacion.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../../test_servidor.dart';

Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 10));

/// Servicio con dos tipos y dos notificaciones guardadas confirmadas.
Future<(SheetsDataService, ServidorSimulado, TipoNotificacion, TipoNotificacion)> _conPlantillas() async {
  final (ds, servidor) = await servicioConServidor();
  final pago = await ds.addTipoNotificacion('Pago quincenal');
  final cumple = await ds.addTipoNotificacion('Cumpleaños');
  await ds.addPlantillaNotificacion(
      tipoId: pago.id, titulo: 'Día de pago', cuerpo: 'Hoy se realizó el pago de su quincena.');
  await ds.addPlantillaNotificacion(tipoId: cumple.id, titulo: 'Feliz cumpleaños', cuerpo: '¡Que lo pases muy bien!');
  return (ds, servidor, pago, cumple);
}

void main() {
  group('PlantillaNotificacion', () {
    test('lee la fila y quita la comilla anti-fórmula del servidor', () {
      final p = PlantillaNotificacion.fromRow(
          const ['pn00000001', 'org1', 'tn00000001', "'-50% hoy", 'Mensaje', 'a@x.com', '2026-10-08']);
      expect((p.id, p.tipoId, p.titulo, p.cuerpo), ('pn00000001', 'tn00000001', '-50% hoy', 'Mensaje'));
      final t = TipoNotificacion.fromRow(const ['tn00000003', 'Cumpleaños', 'inactivo']);
      expect((t.nombre, t.activo), ('Cumpleaños', false));
    });
  });

  group('SheetsDataService', () {
    test('alta con ID del servidor y en la organización actual; editar y eliminar por ID', () async {
      final (ds, servidor, pago, cumple) = await _conPlantillas();
      final alta = servidor.enviados.lastWhere((e) => e['sheet'] == 'plantillas_notificacion');
      expect(alta['action'], 'create');
      expect((alta['data'] as Map).containsKey('id'), isFalse);
      expect(alta['data'], containsPair('organizacion_id', organizacionDePrueba));
      expect(ds.plantillasNotificacion.map((p) => p.id), everyElement(startsWith('pn9')));

      final dia = ds.plantillasNotificacion.firstWhere((p) => p.titulo == 'Día de pago');
      await ds.updatePlantillaNotificacion(dia.id, tipoId: cumple.id, titulo: 'Pago', cuerpo: 'Nuevo texto');
      final edicion = servidor.enviados.last;
      expect(edicion, containsPair('action', 'update'));
      expect(edicion['id'], dia.id);
      expect(edicion['data'], {'tipo_id': cumple.id, 'titulo': 'Pago', 'cuerpo': 'Nuevo texto'});
      expect(ds.plantillaNotificacion(dia.id)!.organizacionId, organizacionDePrueba);

      await ds.deletePlantillaNotificacion(dia.id);
      expect(servidor.enviados.last, containsPair('action', 'delete'));
      expect(ds.plantillaNotificacion(dia.id), isNull);
      expect(pago.id, startsWith('tn9'));
    });

    test('si Sheets no confirma: el alta, la edición y la baja se revierten', () async {
      final (ds, servidor, pago, _) = await _conPlantillas();
      final antes = ds.plantillasNotificacion.length;
      final una = ds.plantillasNotificacion.first;
      servidor.rechazar('sin red');
      await expectLater(ds.addPlantillaNotificacion(tipoId: pago.id, titulo: 'X', cuerpo: 'Y'), throwsA(isA<StateError>()));
      await expectLater(ds.updatePlantillaNotificacion(una.id, tipoId: pago.id, titulo: 'Otro', cuerpo: 'Y'),
          throwsA(isA<StateError>()));
      await expectLater(ds.deletePlantillaNotificacion(una.id), throwsA(isA<StateError>()));
      expect(ds.plantillasNotificacion.length, antes);
      expect(ds.plantillaNotificacion(una.id), una);
    });

    test('valida tipo, título, mensaje y tipos repetidos sin escribir', () async {
      final (ds, servidor, pago, _) = await _conPlantillas();
      final antes = servidor.enviados.length;
      await expectLater(ds.addPlantillaNotificacion(tipoId: 'tn-x', titulo: 'T', cuerpo: 'C'), throwsA(isA<ArgumentError>()));
      await expectLater(ds.addPlantillaNotificacion(tipoId: pago.id, titulo: ' ', cuerpo: 'C'), throwsA(isA<ArgumentError>()));
      await expectLater(
          ds.addPlantillaNotificacion(tipoId: pago.id, titulo: 'T', cuerpo: 'x' * 501), throwsA(isA<ArgumentError>()));
      await expectLater(ds.addTipoNotificacion('pago QUINCENAL'), throwsA(isA<ArgumentError>()));
      expect(servidor.enviados.length, antes);
    });

    test('solo se ven las de la organización actual', () async {
      final (ds, _, _, _) = await _conPlantillas();
      expect(ds.plantillasNotificacion, hasLength(2));
      ds.setCurrentOrganizacion('otra-org');
      expect(ds.plantillasNotificacion, isEmpty);
    });
  });

  group('PlantillasNotificacionCubit', () {
    test('filtra por tipo y cuenta por tipo', () async {
      final (ds, _, pago, cumple) = await _conPlantillas();
      final cubit = PlantillasNotificacionCubit(dataService: ds);
      expect(cubit.state.filtradas, hasLength(2));
      expect(cubit.state.cantidadPorTipo, {pago.id: 1, cumple.id: 1});
      cubit.filtrarPorTipo(cumple.id);
      expect(cubit.state.filtradas.single.titulo, 'Feliz cumpleaños');
      expect(cubit.state.nombreTipo(cumple.id), 'Cumpleaños');
      cubit.filtrarPorTipo(null);
      expect(cubit.state.filtradas, hasLength(2));
      await cubit.close();
    });

    test('eliminar informa éxito; si falla, el error', () async {
      final (ds, servidor, _, _) = await _conPlantillas();
      final cubit = PlantillasNotificacionCubit(dataService: ds);
      await cubit.eliminar(cubit.state.plantillas.first);
      expect(cubit.state.plantillas, hasLength(1));
      servidor.rechazar('sin red');
      await cubit.eliminar(cubit.state.plantillas.first);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.plantillas, hasLength(1));
      await cubit.close();
    });
  });

  group('PlantillaFormCubit', () {
    test('valida antes de guardar y guarda una nueva', () async {
      final (ds, _, pago, _) = await _conPlantillas();
      final cubit = PlantillaFormCubit(dataService: ds);
      await cubit.guardar(titulo: '', cuerpo: '');
      expect(cubit.state.errores.keys, containsAll(CampoPlantilla.values));
      cubit.elegirTipo(pago.id);
      await cubit.guardar(titulo: 'Recordatorio', cuerpo: 'Mañana vence su cuota.');
      expect(cubit.state.guardada, isTrue);
      expect(ds.plantillasNotificacion.any((p) => p.titulo == 'Recordatorio'), isTrue);
      await cubit.close();
    });

    test('edita la existente y crea un tipo nuevo desde el formulario', () async {
      final (ds, servidor, _, _) = await _conPlantillas();
      final p = ds.plantillasNotificacion.first;
      final cubit = PlantillaFormCubit(dataService: ds, plantilla: p);
      expect(cubit.esEdicion, isTrue);
      expect(await cubit.crearTipo('Reunión'), isTrue);
      final reunion = ds.tiposNotificacion.firstWhere((t) => t.nombre == 'Reunión');
      expect(cubit.state.tipoId, reunion.id);
      await cubit.guardar(titulo: p.titulo, cuerpo: 'Texto editado');
      expect(servidor.enviados.last['action'], 'update');
      expect(ds.plantillaNotificacion(p.id)!.tipoId, reunion.id);
      expect(await cubit.crearTipo('reunión'), isFalse, reason: 'repetido');
      expect(cubit.state.errorMessage, contains('Ya existe'));
      await cubit.close();
    });
  });

  group('EnviarNotificacionCubit con una notificación guardada', () {
    test('envía el título y el mensaje guardados; si la borran, queda sin plantilla', () async {
      final (ds, servidor, _, _) = await _conPlantillas();
      final p = ds.plantillasNotificacion.firstWhere((x) => x.titulo == 'Día de pago');
      final cubit = EnviarNotificacionCubit(dataService: ds, plantillaId: p.id);
      await _esperar();
      expect(cubit.state.plantilla, p);
      expect(cubit.state.nombreTipo, 'Pago quincenal');
      cubit.cambiarAlcance(AlcanceNotificacion.global);
      await cubit.enviarPlantilla();
      final envio = servidor.enviados.lastWhere((e) => e['action'] == 'enviar_notificacion');
      expect(envio['data'], containsPair('titulo', 'Día de pago'));
      expect(envio['data'], containsPair('cuerpo', 'Hoy se realizó el pago de su quincena.'));

      await ds.deletePlantillaNotificacion(p.id);
      expect(cubit.state.plantilla, isNull);
      await cubit.enviarPlantilla();
      expect(cubit.state.mensaje, 'Esta notificación ya no existe.');
      await cubit.close();
    });
  });

  testWidgets('el listado se ve en pantalla chica, con filtros y botones', (tester) async {
    tester.view.physicalSize = const Size(392 * 2.8, 800 * 2.8);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final (ds, servidor) = await servicioConServidor(inicializar: false);
    await tester.runAsync(() async {
      final tipo = await ds.addTipoNotificacion('Recordatorio de pago');
      await ds.addPlantillaNotificacion(
          tipoId: tipo.id,
          titulo: 'Su cuota vence mañana y es importante que la pague a tiempo',
          cuerpo: 'Le recordamos que mañana vence su cuota. ' * 5);
    });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: NotificacionesPage(dataService: ds)));
    await tester.pump();
    expect(find.text('Todas (1)'), findsOneWidget);
    expect(find.text('Recordatorio de pago (1)'), findsOneWidget);
    expect(find.text('Ver'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar notificación'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(servidor.enviados, isNotEmpty);
  });
}
