import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../../../models/plantilla_notificacion.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';

/// Campos validables del formulario de una notificación guardada.
enum CampoPlantilla { tipo, titulo, cuerpo }

/// Estado del formulario de alta/edición de una notificación guardada.
class PlantillaFormState extends Equatable {
  /// Tipos activos para elegir (más el de la plantilla, aunque esté inactivo).
  final List<TipoNotificacion> tipos;
  final String? tipoId;
  final Map<CampoPlantilla, String> errores;
  final bool guardando;
  final bool creandoTipo;

  /// Se guardó (el formulario se cierra).
  final bool guardada;

  /// Error del servidor o de un tipo nuevo (transitorio).
  final String? errorMessage;

  const PlantillaFormState({
    this.tipos = const [],
    this.tipoId,
    this.errores = const {},
    this.guardando = false,
    this.creandoTipo = false,
    this.guardada = false,
    this.errorMessage,
  });

  PlantillaFormState copyWith({
    List<TipoNotificacion>? tipos,
    String? tipoId,
    Map<CampoPlantilla, String>? errores,
    bool? guardando,
    bool? creandoTipo,
    bool? guardada,
    String? errorMessage,
  }) =>
      PlantillaFormState(
        tipos: tipos ?? this.tipos,
        tipoId: tipoId ?? this.tipoId,
        errores: errores ?? this.errores,
        guardando: guardando ?? this.guardando,
        creandoTipo: creandoTipo ?? this.creandoTipo,
        guardada: guardada ?? this.guardada,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [tipos, tipoId, errores, guardando, creandoTipo, guardada, errorMessage];
}

/// Alta y edición de una notificación guardada: tipo (con alta de tipos
/// nuevos), título y mensaje. Delega en [SheetsDataService].
class PlantillaFormCubit extends Cubit<PlantillaFormState> {
  final SheetsDataService dataService;

  /// `null` = notificación nueva.
  final PlantillaNotificacion? plantilla;

  PlantillaFormCubit({required this.dataService, this.plantilla})
      : super(PlantillaFormState(tipoId: plantilla?.tipoId)) {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  bool get esEdicion => plantilla != null;

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final tipos = dataService.tiposNotificacion.where((t) => t.activo || t.id == plantilla?.tipoId).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    emit(state.copyWith(tipos: tipos));
  }

  void elegirTipo(String tipoId) {
    emit(state.copyWith(tipoId: tipoId, errores: Map.of(state.errores)..remove(CampoPlantilla.tipo)));
  }

  /// Limpia el error de un campo cuando se lo vuelve a editar.
  void campoEditado(CampoPlantilla campo) {
    if (state.errores.containsKey(campo)) emit(state.copyWith(errores: Map.of(state.errores)..remove(campo)));
  }

  /// Agrega un tipo al catálogo y lo deja elegido. Devuelve `true` si se creó.
  Future<bool> crearTipo(String nombre) async {
    if (state.creandoTipo) return false;
    emit(state.copyWith(creandoTipo: true));
    try {
      final tipo = await dataService.addTipoNotificacion(nombre);
      if (isClosed) return true;
      emit(state.copyWith(
          creandoTipo: false, tipoId: tipo.id, errores: Map.of(state.errores)..remove(CampoPlantilla.tipo)));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(creandoTipo: false, errorMessage: _mensaje(e, 'No se pudo crear el tipo')));
      return false;
    }
  }

  Future<void> guardar({required String titulo, required String cuerpo}) async {
    if (state.guardando) return;
    final t = titulo.trim();
    final c = cuerpo.trim();
    final errores = <CampoPlantilla, String>{
      if (state.tipoId == null || !state.tipos.any((x) => x.id == state.tipoId))
        CampoPlantilla.tipo: 'Elegí el tipo de notificación.',
      if (t.isEmpty)
        CampoPlantilla.titulo: 'Escribí un título.'
      else if (t.length > PlantillaNotificacion.maxTitulo)
        CampoPlantilla.titulo: 'Hasta ${PlantillaNotificacion.maxTitulo} caracteres.',
      if (c.isEmpty)
        CampoPlantilla.cuerpo: 'Escribí el mensaje.'
      else if (c.length > PlantillaNotificacion.maxCuerpo)
        CampoPlantilla.cuerpo: 'Hasta ${PlantillaNotificacion.maxCuerpo} caracteres.',
    };
    if (errores.isNotEmpty) {
      emit(state.copyWith(errores: errores));
      return;
    }
    emit(state.copyWith(guardando: true, errores: const {}));
    try {
      final p = plantilla;
      if (p == null) {
        await dataService.addPlantillaNotificacion(tipoId: state.tipoId!, titulo: t, cuerpo: c);
      } else {
        await dataService.updatePlantillaNotificacion(p.id, tipoId: state.tipoId!, titulo: t, cuerpo: c);
      }
      if (!isClosed) emit(state.copyWith(guardando: false, guardada: true));
    } catch (e, st) {
      Logger.error('PlantillaFormCubit: no se pudo guardar la notificación', e, st);
      if (!isClosed) emit(state.copyWith(guardando: false, errorMessage: _mensaje(e, 'No se pudo guardar')));
    }
  }

  static String _mensaje(Object e, String prefijo) => switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => '$message',
        _ => '$prefijo: $e',
      };

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
