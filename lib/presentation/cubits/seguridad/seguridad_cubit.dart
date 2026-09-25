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

    Logger.warning(
      'Método de seguridad "$metodoActivo" no es compatible con este dispositivo; '
      'se restablece a "Ninguno".',
    );
    dataService.setMetodoSeguridad(null);
  }

  void setMetodoSeguridad(String? metodo) {
    Logger.info('SeguridadCubit: Cambiando método de seguridad a: $metodo');
    dataService.setMetodoSeguridad(metodo);
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
