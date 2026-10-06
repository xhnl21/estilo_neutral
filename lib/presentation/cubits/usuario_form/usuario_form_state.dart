import 'package:equatable/equatable.dart';
import '../../../models/organizacion.dart';

enum UsuarioFormStatus { editando, guardando, guardado, error }

/// Campos validables del formulario de usuario.
enum UsuarioFormField { email, cedula, organizacion }

/// Estado inmutable del formulario de alta/edición de usuarios autorizados.
class UsuarioFormState extends Equatable {
  final UsuarioFormStatus status;
  final bool isEditing;

  /// Tipos de documento activos, más el del usuario aunque esté inactivo
  /// (se muestra el que realmente tiene, no otro).
  final List<String> tiposDocumento;
  final String tipoDocumento;

  final List<Organizacion> organizaciones;

  /// Organización elegida; `null` si la de la membresía ya no existe.
  final String? organizacionId;

  /// Valores iniciales para los `TextEditingController` de la vista.
  final String emailInicial;
  final String nombreInicial;
  final String cedulaInicial;

  final Map<UsuarioFormField, String> errors;

  /// Mensaje del guardado (éxito o error), transitorio.
  final String? resultMessage;

  const UsuarioFormState({
    this.status = UsuarioFormStatus.editando,
    required this.isEditing,
    required this.tiposDocumento,
    required this.tipoDocumento,
    required this.organizaciones,
    required this.organizacionId,
    this.emailInicial = '',
    this.nombreInicial = '',
    this.cedulaInicial = '',
    this.errors = const {},
    this.resultMessage,
  });

  bool get isSubmitting => status == UsuarioFormStatus.guardando;

  UsuarioFormState copyWith({
    UsuarioFormStatus? status,
    String? tipoDocumento,
    List<Organizacion>? organizaciones,
    String? organizacionId,
    bool limpiarOrganizacion = false,
    Map<UsuarioFormField, String>? errors,
    String? resultMessage,
  }) {
    return UsuarioFormState(
      status: status ?? this.status,
      isEditing: isEditing,
      tiposDocumento: tiposDocumento,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      organizaciones: organizaciones ?? this.organizaciones,
      organizacionId: limpiarOrganizacion ? null : (organizacionId ?? this.organizacionId),
      emailInicial: emailInicial,
      nombreInicial: nombreInicial,
      cedulaInicial: cedulaInicial,
      errors: errors ?? this.errors,
      resultMessage: resultMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isEditing,
        tiposDocumento,
        tipoDocumento,
        organizaciones.map((o) => '${o.id}|${o.nombre}').join(','),
        organizacionId,
        emailInicial,
        nombreInicial,
        cedulaInicial,
        errors,
        resultMessage,
      ];
}
