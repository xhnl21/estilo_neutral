import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/features/auth/application/auth_cubit.dart';
import 'package:estilo_neutral/features/auth/domain/auth_state.dart';
import 'package:estilo_neutral/features/notificaciones/notificaciones.dart';
import 'package:estilo_neutral/features/notificaciones/infrastructure/push_firebase.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../../test_servidor.dart';

class _PushFalso implements PushGateway {
  bool permiso = true;
  String? token = 'tok-1';
  int tokensEliminados = 0;
  final mostrados = <MensajePush>[];
  final renovado = StreamController<String>.broadcast();
  final primerPlano = StreamController<MensajePush>.broadcast();
  final abiertos = StreamController<MensajePush>.broadcast();
  MensajePush? inicial;

  @override
  bool get disponible => true;
  @override
  String get plataforma => 'android';
  @override
  Future<bool> solicitarPermiso() async => permiso;
  @override
  Future<String?> obtenerToken() async => token;
  @override
  Stream<String> get tokenRenovado => renovado.stream;
  @override
  Stream<MensajePush> get mensajesEnPrimerPlano => primerPlano.stream;
  @override
  Stream<MensajePush> get mensajesAbiertos => abiertos.stream;
  @override
  Future<MensajePush?> mensajeInicial() async => inicial;
  @override
  Future<void> mostrarLocal(MensajePush mensaje) async => mostrados.add(mensaje);
  @override
  Future<void> eliminarToken() async => tokensEliminados++;
  @override
  Future<bool> consumirAvisoRevocacion() async => false;
}

Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late SheetsDataService ds;
  late ServidorSimulado servidor;

  setUp(() async => (ds, servidor) = await servicioConServidor());

  Map<String, dynamic> ultimo(String accion) => servidor.enviados.lastWhere((e) => e['action'] == accion);

  group('mensajeDesde', () {
    test('mensaje solo de datos (envíos actuales): título, cuerpo y ruta de los datos', () {
      final m = mensajeDesde(const RemoteMessage(data: {'titulo': 'Hola', 'cuerpo': 'Texto', 'ruta': '/ventas'}));
      expect(m.titulo, 'Hola');
      expect(m.cuerpo, 'Texto');
      expect(m.ruta, '/ventas');
    });

    test('mensaje con notification (envíos viejos): usa notification', () {
      final m = mensajeDesde(const RemoteMessage(
        notification: RemoteNotification(title: 'Viejo', body: 'Cuerpo'),
        data: {'titulo': 'ignorado'},
      ));
      expect(m.titulo, 'Viejo');
      expect(m.cuerpo, 'Cuerpo');
    });
  });

  group('DestinoNotificacion', () {
    test('serializa cada alcance', () {
      expect(const DestinoNotificacion.global().toMap(), {'alcance': 'global'});
      expect(DestinoNotificacion.organizaciones(const ['o1', 'o2']).toMap(), {
        'alcance': 'organizaciones',
        'organizacion_ids': ['o1', 'o2'],
      });
      expect(DestinoNotificacion.usuarios(const [' Ana@X.com ']).toMap(), {
        'alcance': 'usuarios',
        'usuarios': ['ana@x.com'],
      });
    });

    test('sin destinatarios es un error', () {
      expect(DestinoNotificacion.organizaciones(const []).error, isNotNull);
      expect(DestinoNotificacion.usuarios(const []).error, isNotNull);
      expect(const DestinoNotificacion.global().error, isNull);
    });
  });

  group('SheetsDataService', () {
    test('enviarNotificacion manda destino, texto y datos con el usuario de la sesión', () async {
      servidor.respuesta = '{"status":"success","id":"nt00000007","enviados":3,"fallidos":1}';
      final r = await ds.enviarNotificacion(
        destino: DestinoNotificacion.organizaciones(const [organizacionDePrueba, 'org-2']),
        titulo: ' Hola ',
        cuerpo: 'Mensaje',
        datos: {'ruta': '/ventas'},
      );
      expect(r, const ResultadoEnvioNotificacion(id: 'nt00000007', enviados: 3, fallidos: 1));
      final p = ultimo('enviar_notificacion');
      expect(p['usuario_sesion'], 'xhnl21@gmail.com');
      expect(p['data'], {
        'alcance': 'organizaciones',
        'organizacion_ids': [organizacionDePrueba, 'org-2'],
        'titulo': 'Hola',
        'cuerpo': 'Mensaje',
        'datos': {'ruta': '/ventas'},
      });
    });

    test('valida sin enviar nada', () async {
      final antes = servidor.enviados.length;
      await expectLater(
        ds.enviarNotificacion(destino: const DestinoNotificacion.global(), titulo: '', cuerpo: 'x'),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        ds.enviarNotificacion(destino: DestinoNotificacion.usuarios(const []), titulo: 't', cuerpo: 'x'),
        throwsA(isA<ArgumentError>()),
      );
      expect(servidor.enviados.length, antes);
    });

    test('un rechazo del servidor llega como StateError con su mensaje', () async {
      servidor.rechazar('FCM no está configurado');
      await expectLater(
        ds.enviarNotificacion(destino: const DestinoNotificacion.global(), titulo: 't', cuerpo: 'c'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('FCM no está configurado'))),
      );
    });

    test('registrar y eliminar dispositivo', () async {
      await ds.registrarDispositivo(token: 'tok-9', plataforma: 'ios');
      expect(ultimo('registrar_dispositivo')['data'], {'token': 'tok-9', 'plataforma': 'ios'});
      ds.setCurrentUsuario(null); // al cerrar sesión ya no hay usuario actual
      await ds.eliminarDispositivo(token: 'tok-9', usuarioEmail: 'XHNL21@gmail.com');
      final p = ultimo('eliminar_dispositivo');
      expect(p['usuario_sesion'], 'xhnl21@gmail.com');
      expect(p['data'], {'token': 'tok-9'});
    });
  });

  group('EnviarNotificacionCubit', () {
    test('agrupa los usuarios por su organización', () async {
      final cubit = EnviarNotificacionCubit(dataService: ds);
      final emails = cubit.state.usuariosPorOrganizacion[organizacionDePrueba]!.map((u) => u.email);
      expect(emails, containsAll(['xhnl21@gmail.com', 'neidapulgar1989@gmail.com']));
      await cubit.close();
    });

    test('valida título, mensaje y destinatarios', () async {
      final cubit = EnviarNotificacionCubit(dataService: ds);
      await cubit.enviar(titulo: '', cuerpo: '');
      expect(cubit.state.errores.keys,
          containsAll([CampoNotificacion.titulo, CampoNotificacion.cuerpo, CampoNotificacion.destino]));
      cubit.campoEditado(CampoNotificacion.titulo);
      expect(cubit.state.errores.containsKey(CampoNotificacion.titulo), isFalse);
      await cubit.close();
    });

    test('elegir "Todos" de una organización y enviar a esos usuarios', () async {
      servidor.respuesta = '{"status":"success","id":"nt00000001","enviados":2,"fallidos":0}';
      final cubit = EnviarNotificacionCubit(dataService: ds);
      cubit.cambiarAlcance(AlcanceNotificacion.usuarios);
      cubit.alternarUsuariosDeOrganizacion(organizacionDePrueba);
      expect(cubit.state.usuariosSeleccionados, containsAll(['xhnl21@gmail.com', 'neidapulgar1989@gmail.com']));
      await cubit.enviar(titulo: 'Aviso', cuerpo: 'Hola');
      expect(cubit.state.status, EnviarNotificacionStatus.enviada);
      expect(cubit.state.mensaje, contains('2 dispositivos'));
      expect((ultimo('enviar_notificacion')['data'] as Map)['alcance'], 'usuarios');
      cubit.alternarUsuariosDeOrganizacion(organizacionDePrueba);
      expect(cubit.state.usuariosSeleccionados, isEmpty);
      await cubit.close();
    });

    test('sin dispositivos registrados lo dice', () async {
      servidor.respuesta = '{"status":"success","id":"nt00000001","enviados":0,"fallidos":0}';
      final cubit = EnviarNotificacionCubit(dataService: ds);
      cubit.cambiarAlcance(AlcanceNotificacion.global);
      await cubit.enviar(titulo: 'Aviso', cuerpo: 'Hola');
      expect(cubit.state.mensaje, contains('ninguno'));
      await cubit.close();
    });

    test('un error del servidor queda en el estado', () async {
      servidor.rechazar('FCM no está configurado');
      final cubit = EnviarNotificacionCubit(dataService: ds);
      cubit.cambiarAlcance(AlcanceNotificacion.organizaciones);
      cubit.alternarOrganizacion(organizacionDePrueba);
      await cubit.enviar(titulo: 'Aviso', cuerpo: 'Hola');
      expect(cubit.state.status, EnviarNotificacionStatus.error);
      expect(cubit.state.mensaje, contains('FCM no está configurado'));
      await cubit.close();
    });
  });

  group('PushCubit', () {
    late AuthCubit auth;
    late _PushFalso push;
    late List<String> rutas;

    setUp(() {
      auth = AuthCubit(initialState: const AuthState(isAuthenticated: false));
      push = _PushFalso();
      rutas = [];
    });

    PushCubit crear() => PushCubit(gateway: push, dataService: ds, authCubit: auth, navegar: rutas.add);

    test('sin Firebase queda no disponible y no hace nada', () async {
      final cubit = PushCubit(
        gateway: const PushNoDisponible('sin configurar'),
        dataService: ds,
        authCubit: auth,
        navegar: rutas.add,
      );
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      expect(cubit.state.status, PushStatus.noDisponible);
      expect(servidor.enviados.where((e) => e['action'] == 'registrar_dispositivo'), isEmpty);
      await cubit.close();
    });

    test('al iniciar sesión registra el dispositivo; al cerrarla lo borra', () async {
      final cubit = crear();
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      expect(cubit.state.status, PushStatus.registrado);
      expect(ultimo('registrar_dispositivo')['data'], {'token': 'tok-1', 'plataforma': 'android'});

      auth.logout();
      ds.setCurrentUsuario(null);
      await _esperar();
      expect(ultimo('eliminar_dispositivo')['usuario_sesion'], 'xhnl21@gmail.com');
      expect(push.tokensEliminados, 1);
      expect(cubit.state.status, PushStatus.inactivo);
      await cubit.close();
    });

    test('sin permiso no registra', () async {
      push.permiso = false;
      final cubit = crear();
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      expect(cubit.state.status, PushStatus.sinPermiso);
      expect(servidor.enviados.where((e) => e['action'] == 'registrar_dispositivo'), isEmpty);
      await cubit.close();
    });

    test('si FCM renueva el token, lo vuelve a registrar', () async {
      final cubit = crear();
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      push.renovado.add('tok-2');
      await _esperar();
      expect((ultimo('registrar_dispositivo')['data'] as Map)['token'], 'tok-2');
      await cubit.close();
    });

    test('con la app abierta muestra la notificación; al tocarla navega a su ruta', () async {
      final cubit = crear();
      push.primerPlano.add(const MensajePush(titulo: 'Hola', cuerpo: 'x'));
      push.abiertos.add(const MensajePush(datos: {'ruta': '/ventas'}));
      push.abiertos.add(const MensajePush(datos: {'ruta': 'https://otro.sitio'}));
      await _esperar();
      expect(push.mostrados.single.titulo, 'Hola');
      expect(rutas, ['/ventas']);
      await cubit.close();
    });

    test('el push silencioso de sesión revocada no se muestra y relee el acceso (con un reintento)', () async {
      final cubit = PushCubit(
        gateway: push,
        dataService: ds,
        authCubit: auth,
        navegar: rutas.add,
        esperaReintento: Duration.zero,
      );
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      servidor.lecturas.clear();
      push.primerPlano.add(const MensajePush(datos: {'tipo': tipoSesionRevocada, 'motivo': 'La cuenta fue inactivada.'}));
      await _esperar();
      expect(push.mostrados, isEmpty);
      // La copia local todavía lo muestra activo: relee y reintenta una vez.
      expect(servidor.lecturas['usuarios'], 2);
      await cubit.close();
    });

    test('pushes silenciosos de límites y uso: no se muestran y refrescan las pantallas', () async {
      final cubit = crear();
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      servidor.lecturas.clear();
      final version = ds.versionNotificaciones;
      push.primerPlano.add(const MensajePush(datos: {'tipo': tipoConfigNotificaciones}));
      await _esperar();
      expect(servidor.lecturas['config_notificaciones'], 1, reason: 'relee los límites');
      push.primerPlano.add(const MensajePush(datos: {'tipo': tipoUsoNotificaciones}));
      await _esperar();
      expect(push.mostrados, isEmpty);
      expect(ds.versionNotificaciones, version + 2);
      expect(servidor.lecturas['config_notificaciones'], 1, reason: 'el uso no relee la hoja');
      await cubit.close();
    });

    test('esSilencioso: los tipos del servidor', () {
      expect(const MensajePush(datos: {'tipo': 'uso_notificaciones'}).esSilencioso, isTrue);
      expect(const MensajePush(datos: {'tipo': 'sesion_revocada'}).esSilencioso, isTrue);
      expect(const MensajePush(titulo: 'Hola', datos: {'ruta': '/ventas'}).esSilencioso, isFalse);
    });

    test('push de sesión revocada sin sesión abierta: no hace nada', () async {
      final cubit = crear();
      servidor.lecturas.clear();
      push.primerPlano.add(const MensajePush(datos: {'tipo': tipoSesionRevocada}));
      await _esperar();
      expect(push.mostrados, isEmpty);
      expect(servidor.lecturas, isEmpty);
      await cubit.close();
    });

    test('la notificación que abrió la app navega al iniciar', () async {
      push.inicial = const MensajePush(datos: {'ruta': '/inventario'});
      final cubit = crear();
      await _esperar();
      expect(rutas, ['/inventario']);
      await cubit.close();
    });

    test('si el servidor falla, queda en error sin romper', () async {
      servidor.rechazar('sin red');
      final cubit = crear();
      auth.login(email: 'xhnl21@gmail.com', organizacionId: organizacionDePrueba);
      await _esperar();
      expect(cubit.state.status, PushStatus.error);
      await cubit.close();
    });
  });
}
