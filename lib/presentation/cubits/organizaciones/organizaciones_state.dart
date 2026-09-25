import 'package:equatable/equatable.dart';
import '../../../models/organizacion.dart';
import '../../../models/usuario.dart';

enum OrganizacionesStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Organizaciones (BLoC/Cubit).
class OrganizacionesState extends Equatable {
  final OrganizacionesStatus status;
  final List<Organizacion> organizaciones;
  final List<Usuario> usuarios;
  final bool schemaMultiOrgListo;
  final bool isRefreshing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const OrganizacionesState({
    this.status = OrganizacionesStatus.initial,
    this.organizaciones = const [],
    this.usuarios = const [],
    this.schemaMultiOrgListo = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  OrganizacionesState copyWith({
    OrganizacionesStatus? status,
    List<Organizacion>? organizaciones,
    List<Usuario>? usuarios,
    bool? schemaMultiOrgListo,
    bool? isRefreshing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return OrganizacionesState(
      status: status ?? this.status,
      organizaciones: organizaciones ?? this.organizaciones,
      usuarios: usuarios ?? this.usuarios,
      schemaMultiOrgListo: schemaMultiOrgListo ?? this.schemaMultiOrgListo,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == OrganizacionesStatus.loading || status == OrganizacionesStatus.initial) &&
      organizaciones.isEmpty;

  @override
  List<Object?> get props => [
        status,
        organizaciones,
        usuarios,
        schemaMultiOrgListo,
        isRefreshing,
        errorMessage,
        actionSuccessMessage,
      ];
}
