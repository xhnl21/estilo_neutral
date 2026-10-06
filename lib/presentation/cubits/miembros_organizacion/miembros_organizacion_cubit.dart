import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/models.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'miembros_organizacion_state.dart';

/// Cubit del diálogo de miembros de una organización: listas de miembros y
/// disponibles, el usuario elegido para agregar, y las acciones de agregar
/// y mover. Se resincroniza con [SheetsDataService] cuando cambian las
/// membresías.
class MiembrosOrganizacionCubit extends Cubit<MiembrosOrganizacionState> {
  final SheetsDataService dataService;
  final String organizacionId;

  MiembrosOrganizacionCubit({
    required this.dataService,
    required this.organizacionId,
  }) : super(const MiembrosOrganizacionState()) {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final usuarios = dataService.usuarios;
    final miembros = usuarios
        .where((u) => dataService.organizacionIdForUsuario(u.email) == organizacionId)
        .toList();
    final disponibles = usuarios
        .where((u) => dataService.organizacionIdForUsuario(u.email) != organizacionId)
        .toList();

    // Se conserva la elección del usuario mientras siga disponible.
    final actual = state.seleccionadoEmail;
    final seleccionado = disponibles.any((u) => u.email == actual)
        ? actual
        : disponibles.firstOrNull?.email;

    emit(state.copyWith(
      miembros: miembros,
      disponibles: disponibles,
      seleccionadoEmail: seleccionado,
      clearSeleccionado: seleccionado == null,
    ));
  }

  void seleccionar(String email) {
    emit(state.copyWith(seleccionadoEmail: email));
  }

  /// Agrega a esta organización al usuario elegido (lo saca de la suya).
  Future<void> agregarSeleccionado() async {
    final email = state.seleccionadoEmail;
    final usuario = state.disponibles.where((u) => u.email == email).firstOrNull;
    if (usuario == null || state.isSaving) return;
    await _asignar(usuario, organizacionId, accion: 'agregado a la organización');
  }

  /// Mueve a un miembro de esta organización a [destinoId].
  Future<void> mover(Usuario usuario, String destinoId) async {
    if (state.isSaving) return;
    await _asignar(usuario, destinoId, accion: 'movido de organización');
  }

  Future<void> _asignar(Usuario usuario, String destinoId, {required String accion}) async {
    final nombre = usuario.nombre.isNotEmpty ? usuario.nombre : usuario.email;
    Logger.info('MiembrosOrganizacionCubit: ${usuario.email} → $destinoId');
    emit(state.copyWith(status: MiembrosOrganizacionStatus.saving));
    final ok = await dataService.updateUsuario(usuario, organizacionId: destinoId);
    if (isClosed) return;
    emit(state.copyWith(
      status: MiembrosOrganizacionStatus.idle,
      messageType: ok ? MiembrosMessageType.success : MiembrosMessageType.warning,
      message: ok
          ? '$nombre $accion.'
          : '$nombre $accion solo en este dispositivo: no se pudo sincronizar con Google Sheets.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
