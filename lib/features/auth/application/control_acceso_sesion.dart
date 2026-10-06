import '../../../core/utils/logger.dart';
import '../../../shared/google_sheets/sheets_auth.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'auth_cubit.dart';

/// Cierra la sesión abierta de un usuario que perdió el acceso mientras usaba
/// la app (lo eliminaron de "usuarios", le quitaron la membresía, lo movieron
/// de organización o se borró su organización).
///
/// Respeta la política de cero polling (docs/no_polling_policy.md): no
/// consulta Sheets por su cuenta. Reevalúa [SheetsDataService.resolverAcceso]
/// cada vez que llegan datos nuevos — refresco manual, cualquier alta,
/// edición o baja, o el arranque de la app.
class ControlAccesoSesion {
  final SheetsDataService dataService;
  final AuthCubit authCubit;
  final SheetsAuth? sheetsAuth;

  bool _revocando = false;

  ControlAccesoSesion({
    required this.dataService,
    required this.authCubit,
    this.sheetsAuth,
  }) {
    dataService.addListener(_verificar);
  }

  Future<void> _verificar() async {
    if (_revocando || dataService.isLoading || !authCubit.isAuthenticated) return;
    final email = authCubit.userEmail;
    if (email == null) return;

    final acceso = dataService.resolverAcceso(email);
    final String motivo;
    if (acceso.organizacionId == null) {
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

  void dispose() => dataService.removeListener(_verificar);
}
