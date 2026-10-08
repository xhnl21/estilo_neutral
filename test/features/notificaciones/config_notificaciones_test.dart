import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/features/notificaciones/notificaciones.dart';
import 'package:estilo_neutral/models/config_notificaciones.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../../test_servidor.dart';

Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('ConfigNotificaciones', () {
    test('lee la fila; período o límites ilegibles toman los de por defecto', () {
      final c = ConfigNotificaciones.fromRow(const ['cn00000001', 'org1', 'semana', '50', '200', '2026-10-08', 'a@x.com']);
      expect(c.id, 'cn00000001');
      expect(c.periodo, PeriodoNotificaciones.semana);
      expect(c.limitePorUsuario, 50);
      expect(c.limiteOrganizacion, 200);
      expect(c.actualizadoPor, 'a@x.com');

      final rara = ConfigNotificaciones.fromRow(const ['cn00000002', 'org1', 'anio', 'x', '-3']);
      expect(rara.periodo, PeriodoNotificaciones.hora);
      expect(rara.limitePorUsuario, 30);
      expect(rara.limiteOrganizacion, 0);
    });

    test('sin fila rige lo de siempre: 30 por hora por usuario, sin límite de organización', () {
      const c = ConfigNotificaciones.porDefecto('org1');
      expect(c.esPorDefecto, isTrue);
      expect((c.periodo, c.limitePorUsuario, c.limiteOrganizacion), (PeriodoNotificaciones.hora, 30, 0));
    });

    test('restantes: el menor entre el cupo del usuario y el de la organización; null sin límites', () {
      UsoNotificaciones uso(int lu, int lo, int uu, int uo) => UsoNotificaciones(
          periodo: PeriodoNotificaciones.dia, limitePorUsuario: lu, limiteOrganizacion: lo, usadosUsuario: uu, usadosOrganizacion: uo);
      expect(uso(10, 0, 3, 50).restantes, 7);
      expect(uso(10, 20, 3, 18).restantes, 2);
      expect(uso(10, 20, 12, 18).restantes, 0);
      expect(uso(0, 0, 3, 50).restantes, isNull);
    });
  });

  group('SheetsDataService', () {
    late SheetsDataService ds;
    late ServidorSimulado servidor;

    setUp(() async => (ds, servidor) = await servicioConServidor());

    test('primera vez crea la fila (ID del servidor); después edita la misma', () async {
      expect(ds.configNotificacionesDe(organizacionDePrueba).esPorDefecto, isTrue);
      await ds.guardarConfigNotificaciones(
          organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.dia, limitePorUsuario: 20, limiteOrganizacion: 100);
      final alta = servidor.enviados.last;
      expect(alta['action'], 'create');
      expect(alta['sheet'], 'config_notificaciones');
      expect((alta['data'] as Map).containsKey('id'), isFalse);
      expect(alta['data'], containsPair('periodo', 'dia'));
      expect(alta['data'], containsPair('actualizado_por', 'xhnl21@gmail.com'));
      final creada = ds.configNotificacionesDe(organizacionDePrueba);
      expect(creada.id, 'cn90000001');
      expect(creada.limiteOrganizacion, 100);

      await ds.guardarConfigNotificaciones(
          organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.mes, limitePorUsuario: 0, limiteOrganizacion: 500);
      final edicion = servidor.enviados.last;
      expect(edicion['action'], 'update');
      expect(edicion['id'], 'cn90000001');
      expect(ds.configNotificacionesDe(organizacionDePrueba).periodo, PeriodoNotificaciones.mes);

      final antes = servidor.enviados.length;
      await ds.guardarConfigNotificaciones(
          organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.mes, limitePorUsuario: 0, limiteOrganizacion: 500);
      expect(servidor.enviados.length, antes, reason: 'sin cambios no escribe');
    });

    test('si Sheets no confirma, se revierte', () async {
      servidor.rechazar('sin red');
      await expectLater(
        ds.guardarConfigNotificaciones(
            organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.dia, limitePorUsuario: 1, limiteOrganizacion: 1),
        throwsA(isA<StateError>()),
      );
      expect(ds.configNotificacionesDe(organizacionDePrueba).esPorDefecto, isTrue);
    });

    test('valores inválidos u organización inexistente no se envían', () async {
      await expectLater(
        ds.guardarConfigNotificaciones(
            organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.dia, limitePorUsuario: -1, limiteOrganizacion: 0),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        ds.guardarConfigNotificaciones(
            organizacionId: 'no-existe', periodo: PeriodoNotificaciones.dia, limitePorUsuario: 1, limiteOrganizacion: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(servidor.enviados.where((e) => e['sheet'] == 'config_notificaciones'), isEmpty);
    });

    test('usoNotificaciones lee la respuesta del servidor', () async {
      servidor.respuesta = jsonEncode({
        'status': 'success', 'periodo': 'semana', 'limite_por_usuario': 10, 'limite_organizacion': 40,
        'usados_usuario': 4, 'usados_organizacion': 39, 'renueva': '2026-10-12T04:00:00.000Z',
      });
      final uso = await ds.usoNotificaciones();
      expect(servidor.enviados.last['action'], 'uso_notificaciones');
      expect(uso.periodo, PeriodoNotificaciones.semana);
      expect(uso.restantes, 1);
      expect(uso.renueva, DateTime.utc(2026, 10, 12, 4).toLocal());
    });
  });

  group('ConfigNotificacionesCubit', () {
    late SheetsDataService ds;
    late ServidorSimulado servidor;

    setUp(() async => (ds, servidor) = await servicioConServidor());

    test('una fila por organización, con lo que le rige hoy', () async {
      final cubit = ConfigNotificacionesCubit(dataService: ds);
      expect(cubit.state.filas.map((f) => f.organizacion.id), containsAll(ds.organizaciones.map((o) => o.id)));
      expect(cubit.state.filas.every((f) => f.config.esPorDefecto), isTrue);
      await cubit.close();
    });

    test('valida los números antes de guardar', () async {
      final cubit = ConfigNotificacionesCubit(dataService: ds);
      await cubit.guardar(
          organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.dia, limitePorUsuario: '', limiteOrganizacion: '999999');
      expect(cubit.state.erroresFormulario.keys,
          containsAll([CampoConfigNotificaciones.limitePorUsuario, CampoConfigNotificaciones.limiteOrganizacion]));
      expect(servidor.enviados.where((e) => e['sheet'] == 'config_notificaciones'), isEmpty);
      cubit.campoEditado(CampoConfigNotificaciones.limitePorUsuario);
      expect(cubit.state.erroresFormulario.keys, [CampoConfigNotificaciones.limiteOrganizacion]);
      await cubit.close();
    });

    test('guardar actualiza la fila y avisa a la vista', () async {
      final cubit = ConfigNotificacionesCubit(dataService: ds);
      await cubit.guardar(
          organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.semana, limitePorUsuario: '15', limiteOrganizacion: '0');
      await _esperar();
      final fila = cubit.state.filas.firstWhere((f) => f.organizacion.id == organizacionDePrueba);
      expect(fila.config.periodo, PeriodoNotificaciones.semana);
      expect(fila.config.limitePorUsuario, 15);
      await cubit.close();
    });

    test('si Sheets no confirma, muestra el error', () async {
      servidor.rechazar('sin red');
      final cubit = ConfigNotificacionesCubit(dataService: ds);
      await cubit.guardar(
          organizacionId: organizacionDePrueba, periodo: PeriodoNotificaciones.dia, limitePorUsuario: '1', limiteOrganizacion: '1');
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.guardando, isFalse);
      await cubit.close();
    });
  });

  group('EnviarNotificacionCubit', () {
    String uso({required int usados, int limite = 5}) => jsonEncode({
          'status': 'success', 'periodo': 'dia', 'limite_por_usuario': limite, 'limite_organizacion': 0,
          'usados_usuario': usados, 'usados_organizacion': usados, 'renueva': '2026-10-09T04:00:00.000Z',
        });

    test('al entrar sin cupo avisa con el motivo (para el diálogo)', () async {
      final (ds, servidor) = await servicioConServidor();
      servidor.respuesta = uso(usados: 5);
      final cubit = EnviarNotificacionCubit(dataService: ds);
      final avisos = <String>[];
      final sub = cubit.stream.where((s) => s.avisoCupo != null).listen((s) => avisos.add(s.avisoCupo!));
      await _esperar();
      expect(avisos.single, startsWith('Llegaste a tu límite de 5 notificaciones hoy.'));
      expect(avisos.single, contains('Se renueva el'));
      await sub.cancel();
      await cubit.close();
    });

    test('si el servidor rechaza por límite: diálogo con su motivo, sin SnackBar', () async {
      final (ds, servidor) = await servicioConServidor();
      servidor.respuesta = uso(usados: 1);
      final cubit = EnviarNotificacionCubit(dataService: ds);
      await _esperar();
      expect(cubit.state.sinCupo, isFalse);
      cubit.cambiarAlcance(AlcanceNotificacion.global);
      servidor.respuesta = jsonEncode({
        'status': 'error', 'code': 'limite_notificaciones',
        'message': 'Tu organización llegó a su límite de 3 notificaciones hoy. Se renueva el 09/10/2026 a las 00:00.',
      });
      final avisos = <String>[];
      final sub = cubit.stream.where((s) => s.avisoCupo != null).listen((s) => avisos.add(s.avisoCupo!));
      await cubit.enviar(titulo: 'T', cuerpo: 'C');
      await _esperar();
      expect(avisos, ['Tu organización llegó a su límite de 3 notificaciones hoy. Se renueva el 09/10/2026 a las 00:00.']);
      expect(cubit.state.mensaje, isNull);
      expect(cubit.state.enviando, isFalse);
      await sub.cancel();
      await cubit.close();
    });

    test('un aviso de cambios (push silencioso) vuelve a consultar el cupo y avisa si se agotó', () async {
      final (ds, servidor) = await servicioConServidor();
      servidor.respuesta = uso(usados: 1);
      final cubit = EnviarNotificacionCubit(dataService: ds);
      await _esperar();
      servidor.respuesta = uso(usados: 5);
      final avisos = <String>[];
      final sub = cubit.stream.where((s) => s.avisoCupo != null).listen((s) => avisos.add(s.avisoCupo!));
      await ds.releerNotificaciones();
      await _esperar();
      expect(cubit.state.sinCupo, isTrue);
      expect(avisos, hasLength(1));
      expect(servidor.enviados.where((e) => e['action'] == 'uso_notificaciones'), hasLength(2));
      await sub.cancel();
      await cubit.close();
    });

    test('muestra el cupo y lo marca agotado', () async {
      final (ds, servidor) = await servicioConServidor();
      servidor.respuesta = jsonEncode({
        'status': 'success', 'periodo': 'dia', 'limite_por_usuario': 5, 'limite_organizacion': 0,
        'usados_usuario': 5, 'usados_organizacion': 9, 'renueva': '2026-10-09T04:00:00.000Z',
      });
      final cubit = EnviarNotificacionCubit(dataService: ds);
      await _esperar();
      expect(cubit.state.uso?.restantes, 0);
      expect(cubit.state.sinCupo, isTrue);
      await cubit.close();
    });
  });
}
