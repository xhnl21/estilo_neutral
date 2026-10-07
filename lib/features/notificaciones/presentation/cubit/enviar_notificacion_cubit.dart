import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/usuario.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../domain/destino_notificacion.dart';
import 'enviar_notificacion_state.dart';

/// Cubit de "Enviar notificación": destinatarios (global, organizaciones o
/// usuarios de cualquier organización), validación y envío
/// ([SheetsDataService.enviarNotificacion]).
class EnviarNotificacionCubit extends Cubit<EnviarNotificacionState> {
  final SheetsDataService dataService;

  EnviarNotificacionCubit({required this.dataService}) : super(const EnviarNotificacionState()) {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  /// Organizaciones y usuarios actuales. Lo elegido que ya no existe se
  /// descarta (p. ej. una organización borrada desde otro dispositivo).
  void _syncFromService() {
    final organizaciones = List.of(dataService.organizaciones)..sort((a, b) => a.nombre.compareTo(b.nombre));
    final idsOrg = organizaciones.map((o) => o.id).toSet();
    final porOrg = <String, List<Usuario>>{};
    for (final u in dataService.usuarios) {
      final org = dataService.organizacionIdForUsuario(u.email);
      if (org == null || !idsOrg.contains(org)) continue;
      (porOrg[org] ??= []).add(u);
    }
    for (final lista in porOrg.values) {
      lista.sort((a, b) => a.email.compareTo(b.email));
    }
    final emails = {for (final l in porOrg.values) ...l.map((u) => u.email.toLowerCase())};
    emit(state.copyWith(
      organizaciones: organizaciones,
      usuariosPorOrganizacion: porOrg,
      organizacionesSeleccionadas: state.organizacionesSeleccionadas.intersection(idsOrg),
      usuariosSeleccionados: state.usuariosSeleccionados.intersection(emails),
      errores: state.errores,
    ));
  }

  Map<CampoNotificacion, String> _sinError(CampoNotificacion campo) => Map.of(state.errores)..remove(campo);

  void cambiarAlcance(AlcanceNotificacion alcance) {
    emit(state.copyWith(alcance: alcance, errores: _sinError(CampoNotificacion.destino)));
  }

  void alternarOrganizacion(String id) {
    final sel = Set.of(state.organizacionesSeleccionadas);
    sel.contains(id) ? sel.remove(id) : sel.add(id);
    emit(state.copyWith(organizacionesSeleccionadas: sel, errores: _sinError(CampoNotificacion.destino)));
  }

  void alternarUsuario(String email) {
    final e = email.toLowerCase();
    final sel = Set.of(state.usuariosSeleccionados);
    sel.contains(e) ? sel.remove(e) : sel.add(e);
    emit(state.copyWith(usuariosSeleccionados: sel, errores: _sinError(CampoNotificacion.destino)));
  }

  /// Marca (o desmarca, si ya estaban todos) los usuarios de una organización.
  void alternarUsuariosDeOrganizacion(String organizacionId) {
    final emails = (state.usuariosPorOrganizacion[organizacionId] ?? const []).map((u) => u.email.toLowerCase());
    final sel = Set.of(state.usuariosSeleccionados);
    final todos = emails.every(sel.contains);
    todos ? sel.removeAll(emails) : sel.addAll(emails);
    emit(state.copyWith(usuariosSeleccionados: sel, errores: _sinError(CampoNotificacion.destino)));
  }

  /// Limpia el error de un campo cuando el usuario lo vuelve a editar.
  void campoEditado(CampoNotificacion campo) {
    if (state.errores.containsKey(campo)) emit(state.copyWith(errores: _sinError(campo)));
  }

  Future<void> enviar({required String titulo, required String cuerpo, String? ruta}) async {
    if (state.enviando) return;
    final errores = <CampoNotificacion, String>{
      if (titulo.trim().isEmpty)
        CampoNotificacion.titulo: 'Escribí un título.'
      else if (titulo.trim().length > 100)
        CampoNotificacion.titulo: 'Hasta 100 caracteres.',
      if (cuerpo.trim().isEmpty)
        CampoNotificacion.cuerpo: 'Escribí el mensaje.'
      else if (cuerpo.trim().length > 500)
        CampoNotificacion.cuerpo: 'Hasta 500 caracteres.',
      if (state.destino.error case final e?) CampoNotificacion.destino: e,
    };
    if (errores.isNotEmpty) {
      emit(state.copyWith(status: EnviarNotificacionStatus.editando, errores: errores));
      return;
    }

    emit(state.copyWith(status: EnviarNotificacionStatus.enviando, errores: const {}));
    try {
      final r = await dataService.enviarNotificacion(
        destino: state.destino,
        titulo: titulo,
        cuerpo: cuerpo,
        datos: {if (ruta != null && ruta.isNotEmpty) 'ruta': ruta},
      );
      if (isClosed) return;
      final mensaje = r.sinDestinatarios
          ? 'Se registró la notificación, pero ninguno de esos usuarios tiene un dispositivo con notificaciones activas.'
          : 'Notificación enviada a ${r.enviados} ${r.enviados == 1 ? 'dispositivo' : 'dispositivos'}'
              '${r.fallidos > 0 ? ' (${r.fallidos} sin entregar)' : ''}.';
      emit(state.copyWith(status: EnviarNotificacionStatus.enviada, mensaje: mensaje));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: EnviarNotificacionStatus.error,
        mensaje: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => '$message',
          _ => 'No se pudo enviar la notificación: $e',
        },
      ));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
