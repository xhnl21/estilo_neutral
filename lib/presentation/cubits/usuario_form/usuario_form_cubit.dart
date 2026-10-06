import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/documento_identidad.dart';
import '../../../models/usuario.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'usuario_form_state.dart';

/// Cubit del formulario de alta/edición de usuarios autorizados: catálogos,
/// validación, guardado (que revierte si Sheets falla) y resultado.
class UsuarioFormCubit extends Cubit<UsuarioFormState> {
  final SheetsDataService dataService;

  /// Usuario original cuando se edita; `null` en un alta.
  final Usuario? usuario;

  static final RegExp _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  UsuarioFormCubit({required this.dataService, this.usuario}) : super(_inicial(dataService, usuario)) {
    dataService.addListener(_onDataServiceChanged);
  }

  static UsuarioFormState _inicial(SheetsDataService ds, Usuario? usuario) {
    final tipo = usuario != null && usuario.tipoDocumento.trim().isNotEmpty
        ? usuario.tipoDocumento.trim().toUpperCase()
        : 'V';
    var tipos = ds.tiposDocumentoActivos;
    // Un tipo desactivado sigue siendo el del usuario: se ofrece como opción
    // para no mostrar uno y guardar otro.
    if (!tipos.contains(tipo)) tipos = [...tipos, tipo];

    final organizaciones = List.of(ds.organizaciones);
    final String? organizacionId;
    if (usuario != null) {
      final actual = ds.organizacionIdForUsuario(usuario.email);
      organizacionId = organizaciones.any((o) => o.id == actual) ? actual : null;
    } else {
      final actual = ds.currentOrganizacionId;
      organizacionId = organizaciones.any((o) => o.id == actual) ? actual : organizaciones.firstOrNull?.id;
    }

    return UsuarioFormState(
      isEditing: usuario != null,
      tiposDocumento: tipos,
      tipoDocumento: tipo,
      organizaciones: organizaciones,
      organizacionId: organizacionId,
      emailInicial: usuario?.email ?? '',
      nombreInicial: usuario?.nombre ?? '',
      cedulaInicial: usuario?.cedula ?? '',
    );
  }

  /// Si la organización elegida se borra mientras el formulario está
  /// abierto, se deja sin elegir (en vez de un valor que ya no existe).
  void _onDataServiceChanged() {
    if (isClosed) return;
    final organizaciones = List.of(dataService.organizaciones);
    final sigue = organizaciones.any((o) => o.id == state.organizacionId);
    emit(state.copyWith(organizaciones: organizaciones, limpiarOrganizacion: !sigue));
  }

  void tipoDocumentoChanged(String tipo) {
    emit(state.copyWith(tipoDocumento: tipo, errors: Map.of(state.errors)..remove(UsuarioFormField.cedula)));
  }

  void organizacionChanged(String? organizacionId) {
    emit(state.copyWith(
      organizacionId: organizacionId,
      limpiarOrganizacion: organizacionId == null,
      errors: Map.of(state.errors)..remove(UsuarioFormField.organizacion),
    ));
  }

  /// Limpia el error de un campo cuando el usuario lo vuelve a editar.
  void fieldChanged(UsuarioFormField field) {
    if (!state.errors.containsKey(field)) return;
    emit(state.copyWith(errors: Map.of(state.errors)..remove(field)));
  }

  Future<void> submit({required String email, required String nombre, required String cedula}) async {
    if (state.isSubmitting) return;
    final emailLimpio = usuario?.email ?? email.trim().toLowerCase();
    final cedulaLimpia = DocumentoIdentidad.normalizar(cedula);

    final errors = _validar(email: emailLimpio, cedula: cedulaLimpia);
    if (errors.isNotEmpty) {
      emit(state.copyWith(status: UsuarioFormStatus.editando, errors: errors));
      return;
    }

    final original = usuario;
    final nuevo = original != null
        ? original.copyWith(nombre: nombre.trim(), tipoDocumento: state.tipoDocumento, cedula: cedulaLimpia)
        : Usuario(
            id: '',
            email: emailLimpio,
            nombre: nombre.trim(),
            tipoDocumento: state.tipoDocumento,
            cedula: cedulaLimpia,
          );

    emit(state.copyWith(status: UsuarioFormStatus.guardando, errors: const {}));
    try {
      final ok = state.isEditing
          ? await dataService.updateUsuario(nuevo, organizacionId: state.organizacionId!)
          : await dataService.addUsuario(nuevo, organizacionId: state.organizacionId!);
      if (isClosed) return;
      if (!ok) {
        emit(state.copyWith(
          status: UsuarioFormStatus.error,
          resultMessage: 'No se pudo guardar en Google Sheets. No se cambió nada; probá de nuevo.',
        ));
        return;
      }
      emit(state.copyWith(
        status: UsuarioFormStatus.guardado,
        resultMessage: 'Usuario "$emailLimpio" ${state.isEditing ? 'actualizado' : 'autorizado'}.',
      ));
    } catch (e, stackTrace) {
      Logger.error('UsuarioFormCubit: error al guardar $emailLimpio', e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(
        status: UsuarioFormStatus.error,
        resultMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => message.toString(),
          _ => 'Error al guardar el usuario: $e',
        },
      ));
    }
  }

  Map<UsuarioFormField, String> _validar({required String email, required String cedula}) {
    final errors = <UsuarioFormField, String>{};
    if (!state.isEditing) {
      if (email.isEmpty) {
        errors[UsuarioFormField.email] = 'El correo es obligatorio';
      } else if (!_formatoEmail.hasMatch(email)) {
        errors[UsuarioFormField.email] = 'Correo electrónico inválido';
      } else if (dataService.usuarios.any((u) => u.email.trim().toLowerCase() == email)) {
        errors[UsuarioFormField.email] = 'Ese correo ya tiene acceso';
      }
    }
    if (cedula.isNotEmpty) {
      final error = DocumentoIdentidad.validar(state.tipoDocumento, cedula);
      if (error != null) errors[UsuarioFormField.cedula] = error;
    }
    final orgId = state.organizacionId;
    if (orgId == null || !state.organizaciones.any((o) => o.id == orgId)) {
      errors[UsuarioFormField.organizacion] = 'Elegí una organización';
    }
    return errors;
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
