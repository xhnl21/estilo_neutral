import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum MiembrosOrganizacionStatus { idle, saving }

/// Severidad del mensaje que la vista muestra como SnackBar.
enum MiembrosMessageType { success, warning, error }

/// Estado del diálogo "Usuarios de <organización>".
class MiembrosOrganizacionState extends Equatable {
  final MiembrosOrganizacionStatus status;
  final List<Usuario> miembros;
  final List<Usuario> disponibles;

  /// Email del usuario elegido en "Agregar usuario existente".
  final String? seleccionadoEmail;

  /// Mensaje transitorio (se limpia en la siguiente emisión).
  final String? message;
  final MiembrosMessageType messageType;

  const MiembrosOrganizacionState({
    this.status = MiembrosOrganizacionStatus.idle,
    this.miembros = const [],
    this.disponibles = const [],
    this.seleccionadoEmail,
    this.message,
    this.messageType = MiembrosMessageType.success,
  });

  bool get isSaving => status == MiembrosOrganizacionStatus.saving;

  MiembrosOrganizacionState copyWith({
    MiembrosOrganizacionStatus? status,
    List<Usuario>? miembros,
    List<Usuario>? disponibles,
    String? seleccionadoEmail,
    bool clearSeleccionado = false,
    String? message,
    MiembrosMessageType? messageType,
  }) {
    return MiembrosOrganizacionState(
      status: status ?? this.status,
      miembros: miembros ?? this.miembros,
      disponibles: disponibles ?? this.disponibles,
      seleccionadoEmail: clearSeleccionado
          ? null
          : (seleccionadoEmail ?? this.seleccionadoEmail),
      message: message,
      messageType: messageType ?? MiembrosMessageType.success,
    );
  }

  @override
  List<Object?> get props => [
        status,
        miembros.map((u) => u.email).toList(),
        disponibles.map((u) => u.email).toList(),
        seleccionadoEmail,
        message,
        messageType,
      ];
}
