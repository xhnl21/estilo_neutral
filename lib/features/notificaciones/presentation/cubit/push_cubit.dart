import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../../auth/application/auth_cubit.dart';
import '../../../auth/domain/auth_state.dart';
import '../../infrastructure/push_gateway.dart';
import 'push_state.dart';

/// Notificaciones push del dispositivo (vive toda la app, como AuthCubit):
/// - al iniciar sesión pide permiso y registra el token en la hoja
///   "dispositivos" (y lo vuelve a registrar si FCM lo renueva);
/// - al cerrar sesión borra el token, para que no le lleguen notificaciones
///   de otro usuario a este teléfono;
/// - con la app abierta muestra la notificación localmente, salvo el push
///   silencioso de sesión revocada: ese relee el acceso y, si la cuenta quedó
///   inactiva o eliminada, ControlAccesoSesion cierra la sesión al instante;
/// - al tocar una notificación con `ruta`, navega con [navegar].
class PushCubit extends Cubit<PushState> {
  final PushGateway gateway;
  final SheetsDataService dataService;
  final AuthCubit authCubit;
  final void Function(String ruta) navegar;

  /// Espera antes de releer otra vez si la primera lectura todavía no
  /// mostraba el cambio (la hoja publicada puede tardar unos segundos).
  final Duration esperaReintento;

  final _suscripciones = <StreamSubscription<dynamic>>[];
  String? _token;
  String? _emailRegistrado;

  PushCubit({
    required this.gateway,
    required this.dataService,
    required this.authCubit,
    required this.navegar,
    this.esperaReintento = const Duration(seconds: 5),
  }) : super(PushState(status: gateway.disponible ? PushStatus.inactivo : PushStatus.noDisponible)) {
    if (!gateway.disponible) return;
    _suscripciones
      ..add(authCubit.stream.listen(_alCambiarSesion))
      ..add(gateway.tokenRenovado.listen(_alRenovarToken))
      ..add(gateway.mensajesEnPrimerPlano.listen(_alRecibir))
      ..add(gateway.mensajesAbiertos.listen(_abrir));
    unawaited(_abrirMensajeInicial());
    if (authCubit.isAuthenticated) unawaited(registrar());
  }

  Future<void> _alRecibir(MensajePush mensaje) async {
    if (mensaje.esSesionRevocada) {
      await atenderSesionRevocada();
    } else if (mensaje.esSilencioso) {
      // Límites o uso de las notificaciones: refresca las pantallas abiertas.
      if (authCubit.isAuthenticated) {
        await dataService.releerNotificaciones(config: mensaje.datos['tipo'] == tipoConfigNotificaciones);
      }
    } else {
      await gateway.mostrarLocal(mensaje);
    }
  }

  /// Relee el acceso (no confía a ciegas en el aviso: puede ser viejo y la
  /// cuenta ya estar activa otra vez). Si la cuenta perdió el acceso,
  /// ControlAccesoSesion cierra la sesión con el motivo.
  Future<void> atenderSesionRevocada() async {
    final email = authCubit.userEmail;
    if (!authCubit.isAuthenticated || email == null) return;
    Logger.info('PushCubit: aviso de sesión revocada, se relee el acceso.');
    await dataService.releerAcceso();
    if (isClosed || !authCubit.isAuthenticated) return;
    if (dataService.resolverAcceso(email).organizacionId == null) return;
    await Future<void>.delayed(esperaReintento);
    if (isClosed || !authCubit.isAuthenticated) return;
    await dataService.releerAcceso();
  }

  Future<void> _abrirMensajeInicial() async {
    final mensaje = await gateway.mensajeInicial();
    if (mensaje != null) _abrir(mensaje);
  }

  void _abrir(MensajePush mensaje) {
    final ruta = mensaje.ruta;
    if (ruta != null && ruta.startsWith('/')) navegar(ruta);
  }

  Future<void> _alCambiarSesion(AuthState sesion) async {
    if (sesion.isAuthenticated && sesion.userEmail != _emailRegistrado) {
      await registrar();
    } else if (!sesion.isAuthenticated && _emailRegistrado != null) {
      await _desregistrar();
    }
  }

  Future<void> _alRenovarToken(String token) async {
    _token = token;
    if (authCubit.isAuthenticated) await registrar(token: token);
  }

  /// Pide permiso y registra el token del dispositivo para el usuario actual.
  Future<void> registrar({String? token}) async {
    if (!gateway.disponible || isClosed) return;
    final email = authCubit.userEmail;
    if (email == null) return;
    try {
      if (!await gateway.solicitarPermiso()) {
        if (!isClosed) emit(const PushState(status: PushStatus.sinPermiso));
        return;
      }
      final t = token ?? await gateway.obtenerToken();
      if (t == null) {
        if (!isClosed) emit(const PushState(status: PushStatus.error, mensajeError: 'No se obtuvo el token del dispositivo.'));
        return;
      }
      await dataService.registrarDispositivo(token: t, plataforma: gateway.plataforma);
      _token = t;
      _emailRegistrado = email;
      if (!isClosed) emit(const PushState(status: PushStatus.registrado));
    } catch (e) {
      Logger.warning('PushCubit: no se pudo registrar el dispositivo: $e');
      if (!isClosed) emit(PushState(status: PushStatus.error, mensajeError: '$e'));
    }
  }

  Future<void> _desregistrar() async {
    final token = _token;
    final email = _emailRegistrado;
    _emailRegistrado = null;
    if (token != null && email != null) {
      try {
        await dataService.eliminarDispositivo(token: token, usuarioEmail: email);
      } catch (e) {
        // Si falla (sin red, acceso ya revocado), el servidor igual descarta
        // este token: solo envía a usuarios con acceso y borra los inválidos.
        Logger.warning('PushCubit: no se pudo borrar el dispositivo: $e');
      }
    }
    try {
      await gateway.eliminarToken();
    } catch (_) {}
    _token = null;
    if (!isClosed) emit(const PushState(status: PushStatus.inactivo));
  }

  @override
  Future<void> close() async {
    for (final s in _suscripciones) {
      await s.cancel();
    }
    return super.close();
  }
}
