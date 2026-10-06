import 'package:equatable/equatable.dart';

enum ClienteFormStatus { initial, submitting, success, failure }

/// Severidad del resultado del guardado (la vista lo muestra como SnackBar).
enum ClienteFormResultType { success, warning, error }

/// Campos validables del formulario de cliente.
enum ClienteFormField { nombre, cedula, telefono, email, deuda }

/// Estado inmutable del formulario de alta/edición de clientes.
class ClienteFormState extends Equatable {
  final ClienteFormStatus status;
  final bool isEditing;
  final String id;
  final List<String> tiposDocumento;
  final List<String> codigosTelefono;
  final String tipoDocumento;
  final String codigoTelefono;

  /// Valores iniciales para los `TextEditingController` de la vista.
  final String nombreInicial;
  final String cedulaInicial;
  final String telefonoNumeroInicial;
  final String emailInicial;

  final Map<ClienteFormField, String> errors;

  /// Mensaje a mostrar al terminar el guardado (éxito, advertencia o error).
  final String? resultMessage;
  final ClienteFormResultType resultType;

  const ClienteFormState({
    this.status = ClienteFormStatus.initial,
    required this.isEditing,
    required this.id,
    required this.tiposDocumento,
    required this.codigosTelefono,
    required this.tipoDocumento,
    required this.codigoTelefono,
    this.nombreInicial = '',
    this.cedulaInicial = '',
    this.telefonoNumeroInicial = '',
    this.emailInicial = '',
    this.errors = const {},
    this.resultMessage,
    this.resultType = ClienteFormResultType.success,
  });

  bool get isSubmitting => status == ClienteFormStatus.submitting;

  ClienteFormState copyWith({
    ClienteFormStatus? status,
    String? tipoDocumento,
    String? codigoTelefono,
    Map<ClienteFormField, String>? errors,
    String? resultMessage,
    ClienteFormResultType? resultType,
  }) {
    return ClienteFormState(
      status: status ?? this.status,
      isEditing: isEditing,
      id: id,
      tiposDocumento: tiposDocumento,
      codigosTelefono: codigosTelefono,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      codigoTelefono: codigoTelefono ?? this.codigoTelefono,
      nombreInicial: nombreInicial,
      cedulaInicial: cedulaInicial,
      telefonoNumeroInicial: telefonoNumeroInicial,
      emailInicial: emailInicial,
      errors: errors ?? this.errors,
      resultMessage: resultMessage,
      resultType: resultType ?? ClienteFormResultType.success,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isEditing,
        id,
        tiposDocumento,
        codigosTelefono,
        tipoDocumento,
        codigoTelefono,
        nombreInicial,
        cedulaInicial,
        telefonoNumeroInicial,
        emailInicial,
        errors,
        resultMessage,
        resultType,
      ];
}
