import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/cliente.dart';
import '../../../models/documento_identidad.dart';
import '../../../models/telefono_ve.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'cliente_form_state.dart';

/// Cubit del formulario de alta/edición de clientes: catálogos, validación,
/// estado de guardado y resultado de la sincronización con Google Sheets.
class ClienteFormCubit extends Cubit<ClienteFormState> {
  final SheetsDataService dataService;

  /// Cliente original cuando se edita; `null` en un alta.
  final Cliente? cliente;

  ClienteFormCubit({required this.dataService, this.cliente})
      : super(_initialState(dataService, cliente));

  static ClienteFormState _initialState(
      SheetsDataService dataService, Cliente? cliente) {
    var codigos = dataService.codigosTelefonoActivos;
    var tipos = dataService.tiposDocumentoActivos;

    String codigo = codigos.isNotEmpty ? codigos.first : '0414';
    String numero = '';
    final rawTel = cliente?.telefono.trim() ?? '';
    if (rawTel.isNotEmpty) {
      final telefono = TelefonoVe.parse(rawTel);
      if (telefono != null) {
        codigo = telefono.codigo;
        numero = telefono.numero;
        // Un código desactivado sigue siendo el del cliente: se ofrece como
        // opción para no cambiarle el teléfono en silencio al guardar.
        if (!codigos.contains(codigo)) codigos = [...codigos, codigo];
      } else {
        // Formato no reconocido (p. ej. extranjero): se deja completo en el
        // número para que el usuario lo corrija; la validación lo exige.
        numero = rawTel.replaceAll(RegExp(r'[^0-9]'), '');
      }
    }

    final tipo = cliente != null && cliente.tipoDocumento.isNotEmpty
        ? cliente.tipoDocumento.toUpperCase()
        : 'V';
    // Igual que el código de teléfono: un tipo desactivado sigue siendo el
    // del cliente, se ofrece como opción en vez de mostrar otro.
    if (!tipos.contains(tipo)) tipos = [...tipos, tipo];

    return ClienteFormState(
      isEditing: cliente != null,
      id: cliente?.id ?? dataService.nextClienteId,
      tiposDocumento: tipos,
      codigosTelefono: codigos,
      tipoDocumento: tipo,
      codigoTelefono: codigo,
      nombreInicial: cliente?.nombre ?? '',
      cedulaInicial: cliente?.cedula ?? '',
      telefonoNumeroInicial: numero,
      emailInicial: cliente?.email ?? '',
    );
  }

  void tipoDocumentoChanged(String tipo) {
    final errors = Map.of(state.errors)..remove(ClienteFormField.cedula);
    emit(state.copyWith(tipoDocumento: tipo, errors: errors));
  }

  void codigoTelefonoChanged(String codigo) {
    emit(state.copyWith(codigoTelefono: codigo));
  }

  /// Limpia el error de un campo cuando el usuario lo vuelve a editar.
  void fieldChanged(ClienteFormField field) {
    if (!state.errors.containsKey(field)) return;
    emit(state.copyWith(errors: Map.of(state.errors)..remove(field)));
  }

  /// Valida y guarda. En una edición, el saldo de deuda no se toca: la deuda
  /// real se deriva de las ventas y el campo solo existe como saldo de apertura.
  Future<void> submit({
    required String nombre,
    required String cedula,
    required String telefonoNumero,
    required String email,
    String deuda = '',
  }) async {
    if (state.isSubmitting) return;

    final nombreLimpio = nombre.trim();
    final cedulaLimpia = DocumentoIdentidad.normalizar(cedula);
    final telefonoLimpio = telefonoNumero.replaceAll(RegExp(r'[\s-]'), '');
    final emailLimpio = email.trim().toLowerCase();
    final deudaTexto = deuda.trim().replaceAll(',', '.');
    final deudaUsd = deudaTexto.isEmpty ? 0.0 : double.tryParse(deudaTexto);

    final errors = _validate(
      nombre: nombreLimpio,
      cedula: cedulaLimpia,
      telefono: telefonoLimpio,
      email: emailLimpio,
      deudaUsd: deudaUsd,
    );
    if (errors.isNotEmpty) {
      Logger.warning(
          'ClienteFormCubit: Formulario inválido: ${errors.keys.map((f) => f.name).join(', ')}');
      emit(state.copyWith(status: ClienteFormStatus.initial, errors: errors));
      return;
    }

    // Se guarda en E.164: empieza con "+", así Apps Script lo escribe como
    // texto y Sheets no le quita el 0 inicial (ver TelefonoVe).
    final telefonoCompleto = telefonoLimpio.isNotEmpty
        ? TelefonoVe(codigo: state.codigoTelefono, numero: telefonoLimpio).e164
        : '';
    final original = cliente;
    final nuevoCliente = original != null
        ? original.copyWith(
            nombre: nombreLimpio,
            telefono: telefonoCompleto,
            email: emailLimpio,
            tipoDocumento: state.tipoDocumento,
            cedula: cedulaLimpia,
          )
        : Cliente(
            id: state.id,
            nombre: nombreLimpio,
            telefono: telefonoCompleto,
            email: emailLimpio,
            saldoDeudaUsd: deudaUsd ?? 0.0,
            fechaRegistro: DateTime.now(),
            tipoDocumento: state.tipoDocumento,
            cedula: cedulaLimpia,
          );

    Logger.info(
        'ClienteFormCubit: Guardando cliente: ${nuevoCliente.id} (${nuevoCliente.nombre})');
    Logger.object('Cliente Datos', nuevoCliente.toMap());
    emit(
        state.copyWith(status: ClienteFormStatus.submitting, errors: const {}));

    try {
      if (state.isEditing) {
        await dataService.updateCliente(nuevoCliente);
      } else {
        await dataService.addCliente(nuevoCliente);
      }
      final accion = state.isEditing ? 'actualizado' : 'registrado';
      emit(state.copyWith(
        status: ClienteFormStatus.success,
        resultMessage: 'Cliente "${nuevoCliente.nombre}" $accion y guardado en Google Sheets.',
      ));
    } catch (e, stackTrace) {
      // Si Sheets no lo confirma, el servicio ya revirtió el cambio: el
      // formulario queda abierto para reintentar.
      Logger.error('ClienteFormCubit: Error al guardar cliente ${nuevoCliente.id}', e, stackTrace);
      final mensaje = switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => message.toString(),
        _ => 'Error al guardar cliente: $e',
      };
      emit(state.copyWith(
        status: ClienteFormStatus.failure,
        resultType: ClienteFormResultType.error,
        resultMessage: mensaje,
      ));
    }
  }

  Map<ClienteFormField, String> _validate({
    required String nombre,
    required String cedula,
    required String telefono,
    required String email,
    required double? deudaUsd,
  }) {
    final errors = <ClienteFormField, String>{};

    if (nombre.isEmpty) {
      errors[ClienteFormField.nombre] = 'El nombre es obligatorio';
    } else if (nombre.length < 3) {
      errors[ClienteFormField.nombre] = 'Debe tener al menos 3 caracteres';
    }

    if (cedula.isNotEmpty) {
      final errorFormato =
          DocumentoIdentidad.validar(state.tipoDocumento, cedula);
      if (errorFormato != null) {
        errors[ClienteFormField.cedula] = errorFormato;
      } else {
        final tipo = state.tipoDocumento.toUpperCase();
        final duplicado = dataService.clientes
            .where((c) =>
                c.id != state.id &&
                c.tipoDocumento.toUpperCase() == tipo &&
                DocumentoIdentidad.normalizar(c.cedula) == cedula)
            .firstOrNull;
        if (duplicado != null) {
          errors[ClienteFormField.cedula] =
              'Ya registrado: ${duplicado.nombre} (${duplicado.id})';
        }
      }
    }

    if (telefono.isNotEmpty && !RegExp(r'^\d{7}$').hasMatch(telefono)) {
      errors[ClienteFormField.telefono] = 'Debe tener 7 dígitos';
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors[ClienteFormField.email] = 'Correo electrónico inválido';
    }

    if (!state.isEditing) {
      if (deudaUsd == null) {
        errors[ClienteFormField.deuda] = 'Monto inválido (ej: 25.50)';
      } else if (deudaUsd < 0) {
        errors[ClienteFormField.deuda] = 'No puede ser negativo';
      }
    }

    return errors;
  }
}
