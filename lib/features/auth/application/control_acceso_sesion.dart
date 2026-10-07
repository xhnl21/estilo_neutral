import 'package:flutter/widgets.dart';

import '../../../core/utils/logger.dart';
import '../../../shared/google_sheets/sheets_auth.dart';
import '../../notificaciones/infrastructure/push_gateway.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'auth_cubit.dart';

/// Cierra la sesión abierta de un usuario que perdió el acceso mientras usaba
/// la app (lo eliminaron de "usuarios", le quitaron la membresía, lo movieron
/// de organización o se borró su organización).
///
/// Una revocación hecha desde otro dispositivo se detecta:
/// - **al intentar guardar:** cada escritura lleva el email de la sesión y
///   Apps Script la rechaza si esa cuenta perdió el acceso
///   ([SheetsDataService.accesoRevocadoEnServidor]);
/// - **al volver a la app** desde segundo plano: se releen solo las hojas de
///   acceso ([SheetsDataService.releerAcceso]), como mucho una vez cada
///   [intervaloMinimo];
/// - **al instante, por push silencioso:** al inactivar o eliminar un usuario,
///   el Apps Script le envía un FCM `sesion_revocada`. Con la app abierta lo
///   atiende PushCubit; en segundo plano queda anotado y se atiende al volver
///   (sin esperar [intervaloMinimo]);
/// - con cualquier otra descarga de datos (abrir la app, refrescar).
///
/// Respeta la política de cero polling (docs/no_polling_policy.md): no hay
/// consultas periódicas, solo lecturas puntuales disparadas por un evento.
class ControlAccesoSesion with WidgetsBindingObserver {
  /// Mínimo entre dos relecturas por volver a primer plano: cambiar de app
  /// varias veces seguidas no dispara una lectura por vez.
  static const intervaloMinimo = Duration(seconds: 30);

  final SheetsDataService dataService;
  final AuthCubit authCubit;
  final SheetsAuth? sheetsAuth;
  final PushGateway? push;

  bool _revocando = false;
  DateTime? _ultimaRelectura;
  final bool _observaCicloDeVida;

  ControlAccesoSesion({
    required this.dataService,
    required this.authCubit,
    this.sheetsAuth,
    this.push,
    bool observarCicloDeVida = true,
  }) : _observaCicloDeVida = observarCicloDeVida {
    dataService.addListener(_verificar);
    if (_observaCicloDeVida) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) alVolverAPrimerPlano();
  }

  /// Relee el acceso al volver a la app, salvo que se haya hecho hace menos
  /// de [intervaloMinimo]. Público para tests.
  Future<void> alVolverAPrimerPlano({DateTime? ahora}) async {
    // Se consume siempre, para que un aviso viejo no quede pendiente.
    final avisoRevocacion = await push?.consumirAvisoRevocacion() ?? false;
    if (!authCubit.isAuthenticated) return;
    final momento = ahora ?? DateTime.now();
    final ultima = _ultimaRelectura;
    if (!avisoRevocacion && ultima != null && momento.difference(ultima) < intervaloMinimo) return;
    _ultimaRelectura = momento;
    await dataService.releerAcceso();
  }

  Future<void> _verificar() async {
    if (_revocando || dataService.isLoading || !authCubit.isAuthenticated) return;
    final email = authCubit.userEmail;
    if (email == null) return;

    final acceso = dataService.resolverAcceso(email);
    final rechazoServidor = dataService.accesoRevocadoEnServidor;
    final String motivo;
    if (rechazoServidor != null) {
      motivo = 'Tu acceso fue revocado. $rechazoServidor';
    } else if (acceso.organizacionId == null) {
      motivo = 'Tu acceso fue revocado. ${acceso.motivo}';
    } else if (acceso.organizacionId != authCubit.organizacionId) {
      motivo = 'Tu organización cambió. Volvé a iniciar sesión para continuar.';
    } else {
      return;
    }

    _revocando = true;
    try {
      Logger.warning('ControlAccesoSesion: cerrando la sesión de $email. $motivo');
      // Primero el AuthCubit (el router redirige al login); recién después se
      // limpia el servicio, cuyo notifyListeners vuelve a llamar acá.
      authCubit.logout(motivo: motivo);
      dataService.setCurrentOrganizacion(null);
      dataService.setCurrentUsuario(null);
      // También la sesión de Google: si no, el login la restauraría en silencio.
      await sheetsAuth?.signOut();
    } catch (error, stackTrace) {
      Logger.error('ControlAccesoSesion: error al cerrar la sesión de Google', error, stackTrace);
    } finally {
      _revocando = false;
    }
  }

  void dispose() {
    dataService.removeListener(_verificar);
    if (_observaCicloDeVida) WidgetsBinding.instance.removeObserver(this);
  }
}
