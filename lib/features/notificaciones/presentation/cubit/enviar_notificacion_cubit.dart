import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';

import '../../../../models/usuario.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../domain/correo_clientes.dart';
import '../../domain/destino_notificacion.dart';
import 'enviar_notificacion_state.dart';

/// Cubit de "Enviar notificación": destinatarios (global, organizaciones o
/// usuarios de cualquier organización), validación y envío
/// ([SheetsDataService.enviarNotificacion]).
class EnviarNotificacionCubit extends Cubit<EnviarNotificacionState> {
  final SheetsDataService dataService;

  /// Notificación guardada que se envía (vista "Ver"); `null` = sin plantilla.
  final String? plantillaId;

  /// Última [SheetsDataService.versionNotificaciones] atendida.
  late int _versionNotificaciones;

  EnviarNotificacionCubit({required this.dataService, this.plantillaId}) : super(const EnviarNotificacionState()) {
    _versionNotificaciones = dataService.versionNotificaciones;
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
    unawaited(cargarUso());
  }

  /// Consulta al servidor cuántos envíos quedan en el período (límites de
  /// "Configuración de notificaciones"). Si falla, no se muestra el cupo.
  /// Si el cupo pasa a agotado, avisa con [EnviarNotificacionState.avisoCupo]
  /// (salvo [avisar] en `false`, cuando el aviso ya se mostró).
  Future<void> cargarUso({bool avisar = true}) async {
    try {
      final uso = await dataService.usoNotificaciones();
      if (isClosed) return;
      final antesAgotado = state.sinCupo;
      final motivo = uso.motivoAgotado;
      emit(state.copyWith(
        uso: uso,
        errores: state.errores,
        avisoCupo: avisar && motivo != null && !antesAgotado ? motivo : null,
      ));
    } catch (e) {
      Logger.warning('EnviarNotificacionCubit: no se pudo consultar el uso de notificaciones: $e');
    }
  }

  void _onDataServiceChanged() {
    if (isClosed) return;
    _syncFromService();
    // Push silencioso: cambiaron los límites o alguien gastó cupo de la
    // organización. Se vuelve a consultar (y se avisa si se agotó).
    if (dataService.versionNotificaciones != _versionNotificaciones) {
      _versionNotificaciones = dataService.versionNotificaciones;
      unawaited(cargarUso());
    }
  }

  /// Organizaciones y usuarios actuales. Lo elegido que ya no existe se
  /// descarta (p. ej. una organización borrada desde otro dispositivo).
  void _syncFromService() {
    final organizaciones = List.of(dataService.organizaciones)..sort((a, b) => a.nombre.compareTo(b.nombre));
    final idsOrg = organizaciones.map((o) => o.id).toSet();
    final porOrg = <String, List<Usuario>>{};
    // Un usuario inactivo no recibe notificaciones (el servidor lo excluye).
    for (final u in dataService.usuarios.where((u) => u.activo)) {
      final org = dataService.organizacionIdForUsuario(u.email);
      if (org == null || !idsOrg.contains(org)) continue;
      (porOrg[org] ??= []).add(u);
    }
    for (final lista in porOrg.values) {
      lista.sort((a, b) => a.email.compareTo(b.email));
    }
    final emails = {for (final l in porOrg.values) ...l.map((u) => u.email.toLowerCase())};
    final id = plantillaId;
    final plantilla = id == null ? null : dataService.plantillaNotificacion(id);
    emit(state.copyWith(
      plantilla: plantilla,
      sinPlantilla: plantilla == null,
      nombreTipo: plantilla == null
          ? ''
          : dataService.tiposNotificacion.where((t) => t.id == plantilla.tipoId).firstOrNull?.nombre ?? 'Sin tipo',
      organizaciones: organizaciones,
      usuariosPorOrganizacion: porOrg,
      organizacionesSeleccionadas: state.organizacionesSeleccionadas.intersection(idsOrg),
      usuariosSeleccionados: state.usuariosSeleccionados.intersection(emails),
      errores: state.errores,
    ));
  }

  Map<CampoNotificacion, String> _sinError(CampoNotificacion campo) => Map.of(state.errores)..remove(campo);

  void cambiarCanal(CanalEnvio canal) => emit(state.copyWith(canal: canal, errores: state.errores));

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

  /// Envía la notificación guardada que se está viendo a los destinatarios
  /// elegidos.
  Future<void> enviarPlantilla() async {
    final p = state.plantilla;
    if (p == null) {
      emit(state.copyWith(
          status: EnviarNotificacionStatus.error, mensaje: 'Esta notificación ya no existe.', errores: state.errores));
      return;
    }
    await enviar(titulo: p.titulo, cuerpo: p.cuerpo);
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
      unawaited(cargarUso());
    } on LimiteNotificacionesAgotado catch (e) {
      // Se agotó mientras escribía (p. ej. otro usuario gastó el cupo de la
      // organización): diálogo con el motivo del servidor y cupo actualizado.
      if (isClosed) return;
      emit(state.copyWith(status: EnviarNotificacionStatus.editando, avisoCupo: e.message));
      unawaited(cargarUso(avisar: false));
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
