import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../../../models/cliente.dart';
import '../../../../models/organizacion.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';

enum EnviarCorreoStatus { editando, enviando, enviado, error }

/// Estado del envío por correo de una notificación guardada a los clientes.
class EnviarCorreoState extends Equatable {
  final EnviarCorreoStatus status;

  /// Organización actual: su nombre y su correo son el remitente visible.
  final Organizacion? organizacion;

  /// Clientes activos de la organización con correo válido.
  final List<Cliente> clientes;

  /// Clientes activos sin correo (no pueden recibir).
  final int sinCorreo;

  /// `true` = a todos los [clientes]; `false` = solo a [seleccionados].
  final bool todos;
  final Set<String> seleccionados;
  final String busqueda;

  /// Correos que Google permite enviar hoy; `null` si no se pudo consultar.
  final int? cupoRestante;

  /// Resultado o error del último envío (transitorio).
  final String? mensaje;

  const EnviarCorreoState({
    this.status = EnviarCorreoStatus.editando,
    this.organizacion,
    this.clientes = const [],
    this.sinCorreo = 0,
    this.todos = true,
    this.seleccionados = const {},
    this.busqueda = '',
    this.cupoRestante,
    this.mensaje,
  });

  bool get enviando => status == EnviarCorreoStatus.enviando;
  bool get organizacionSinCorreo => !(organizacion?.tieneEmail ?? false);

  /// Cuántos recibirían el correo.
  int get cantidadDestinatarios => todos ? clientes.length : seleccionados.length;

  bool get puedeEnviar =>
      !enviando &&
      !organizacionSinCorreo &&
      cantidadDestinatarios > 0 &&
      (cupoRestante == null || cupoRestante! >= cantidadDestinatarios);

  /// Clientes que coinciden con [busqueda] (nombre o correo).
  List<Cliente> get clientesFiltrados {
    final q = busqueda.trim().toLowerCase();
    if (q.isEmpty) return clientes;
    return clientes.where((c) => c.nombre.toLowerCase().contains(q) || c.email.toLowerCase().contains(q)).toList();
  }

  EnviarCorreoState copyWith({
    EnviarCorreoStatus? status,
    Organizacion? organizacion,
    List<Cliente>? clientes,
    int? sinCorreo,
    bool? todos,
    Set<String>? seleccionados,
    String? busqueda,
    int? cupoRestante,
    String? mensaje,
  }) =>
      EnviarCorreoState(
        status: status ?? this.status,
        organizacion: organizacion ?? this.organizacion,
        clientes: clientes ?? this.clientes,
        sinCorreo: sinCorreo ?? this.sinCorreo,
        todos: todos ?? this.todos,
        seleccionados: seleccionados ?? this.seleccionados,
        busqueda: busqueda ?? this.busqueda,
        cupoRestante: cupoRestante ?? this.cupoRestante,
        mensaje: mensaje,
      );

  @override
  List<Object?> get props => [
        status,
        organizacion?.id,
        organizacion?.nombre,
        organizacion?.email,
        clientes.map((c) => '${c.id}|${c.email}').join(','),
        sinCorreo,
        todos,
        seleccionados.toList()..sort(),
        busqueda,
        cupoRestante,
        mensaje,
      ];
}

/// Envía por correo una notificación guardada (asunto = título, mensaje =
/// cuerpo) a los clientes de la organización actual. El servidor usa el
/// nombre y el correo de la organización como remitente visible.
class EnviarCorreoCubit extends Cubit<EnviarCorreoState> {
  final SheetsDataService dataService;
  final String plantillaId;

  EnviarCorreoCubit({required this.dataService, required this.plantillaId}) : super(const EnviarCorreoState()) {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
    unawaited(cargarCupo());
  }

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final orgId = dataService.currentOrganizacionId;
    final org = dataService.organizaciones.where((o) => o.id == orgId).firstOrNull;
    final clientes = List.of(dataService.clientesConEmail)
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final ids = clientes.map((c) => c.id).toSet();
    emit(state.copyWith(
      organizacion: org,
      clientes: clientes,
      sinCorreo: dataService.clientesActivos.length - clientes.length,
      seleccionados: state.seleccionados.intersection(ids),
    ));
  }

  /// Cupo diario de Google. Si falla, no se muestra (el servidor igual lo controla).
  Future<void> cargarCupo() async {
    try {
      final cupo = await dataService.cupoCorreo();
      if (!isClosed) emit(state.copyWith(cupoRestante: cupo));
    } catch (e) {
      Logger.warning('EnviarCorreoCubit: no se pudo consultar el cupo de correos: $e');
    }
  }

  void elegirTodos(bool todos) => emit(state.copyWith(todos: todos));

  void alternarCliente(String id) {
    final sel = Set.of(state.seleccionados);
    sel.contains(id) ? sel.remove(id) : sel.add(id);
    emit(state.copyWith(seleccionados: sel, todos: false));
  }

  void buscar(String texto) => emit(state.copyWith(busqueda: texto));

  Future<void> enviar() async {
    if (!state.puedeEnviar) return;
    final plantilla = dataService.plantillaNotificacion(plantillaId);
    if (plantilla == null) {
      emit(state.copyWith(status: EnviarCorreoStatus.error, mensaje: 'Esta notificación ya no existe.'));
      return;
    }
    emit(state.copyWith(status: EnviarCorreoStatus.enviando));
    try {
      final r = await dataService.enviarCorreoClientes(
        asunto: plantilla.titulo,
        cuerpo: plantilla.cuerpo,
        todos: state.todos,
        clienteIds: state.seleccionados,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: EnviarCorreoStatus.enviado,
        cupoRestante: r.restantes,
        mensaje: 'Correo enviado a ${r.enviados} ${r.enviados == 1 ? 'cliente' : 'clientes'}'
            '${r.fallidos > 0 ? ' (${r.fallidos} sin entregar)' : ''}.',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: EnviarCorreoStatus.error,
        mensaje: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => '$message',
          _ => 'No se pudo enviar el correo: $e',
        },
      ));
      unawaited(cargarCupo());
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
