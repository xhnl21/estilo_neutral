import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/auth/biometric_auth_service.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'seguridad_state.dart';

/// Cubit para gestión de estado del módulo de Seguridad (arquitectura BLoC).
class SeguridadCubit extends Cubit<SeguridadState> {
  final SheetsDataService dataService;
  final BiometricAuthService biometricAuthService;

  SeguridadCubit({
    required this.dataService,
    BiometricAuthService? biometricAuthService,
  })  : biometricAuthService = biometricAuthService ?? BiometricAuthService(),
        super(const SeguridadState()) {
    _init();
  }

  void _init() {
    dataService.addListener(_onDataServiceChanged);
    _detectarCapacidades();
  }

  void _onDataServiceChanged() {
    _syncFromService();
  }

  Future<void> _detectarCapacidades() async {
    final biometrico = await biometricAuthService.isAvailable();
    final faceId = biometrico ? await biometricAuthService.hasFaceId() : false;
    emit(state.copyWith(
      biometricoDisponible: biometrico,
      faceIdDisponible: faceId,
      cargandoCapacidades: false,
    ));
    _syncFromService();
    _corregirMetodoIncompatible();
  }

  void _syncFromService() {
    final activo = dataService.seguridad.metodoActivo;
    emit(state.copyWith(
      status: SeguridadStatus.success,
      metodoActivo: activo,
      clearMetodoActivo: activo == null,
      errorMessage: dataService.errorMessage,
    ));
  }

  void _corregirMetodoIncompatible() {
    final metodoActivo = dataService.seguridad.metodoActivo;
    final esIncompatible = (metodoActivo == 'biometrico' && !state.biometricoDisponible) ||
        (metodoActivo == 'desbloqueo_facial' && !state.faceIdDisponible);
    if (!esIncompatible) return;

    // No se cambia ni se guarda nada: el método es del usuario (vale para
    // todos sus dispositivos) y bajarlo a "Ninguno" desde un teléfono sin el
    // sensor lo desactivaba también en los demás. El login ya resuelve qué
    // verificación usar en cada equipo.
    Logger.warning(
      'Método de seguridad "$metodoActivo" no está disponible en este dispositivo; '
      'se mantiene sin cambios.',
    );
  }

  Future<void> setMetodoSeguridad(String? metodo) async {
    Logger.info('SeguridadCubit: Cambiando método de seguridad a: $metodo');
    try {
      await dataService.setMetodoSeguridad(metodo);
    } on StateError catch (e) {
      if (!isClosed) emit(state.copyWith(errorMessage: e.message));
    }
  }

  /// Ejecuta un respaldo manual de la hoja en el servidor.
  Future<void> realizarRespaldoManual() async {
    Logger.info('SeguridadCubit: Iniciando respaldo manual de la hoja...');
    emit(state.copyWith(
      haciendoRespaldo: true,
      clearErrorRespaldo: true,
      clearMensajeRespaldo: true,
    ));
    try {
      final res = await dataService.respaldarHojaManual();
      final nombre = res['nombre']?.toString() ?? 'Copia de seguridad';
      Logger.info('SeguridadCubit: Respaldo completado con éxito: $nombre');
      if (!isClosed) {
        emit(state.copyWith(
          haciendoRespaldo: false,
          mensajeRespaldo: 'Copia creada exitosamente: $nombre',
        ));
      }
    } catch (e) {
      Logger.error('SeguridadCubit: Error al crear respaldo manual: $e');
      if (!isClosed) {
        final errText = e.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
        emit(state.copyWith(
          haciendoRespaldo: false,
          errorRespaldo: errText,
        ));
      }
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
