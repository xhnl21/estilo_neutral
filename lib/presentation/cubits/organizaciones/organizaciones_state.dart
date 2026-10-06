import 'package:equatable/equatable.dart';
import '../../../models/organizacion.dart';
import '../../../models/tasa_registro.dart';
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

  final String? expandedOrganizacionId;

  /// Datos por organización calculados en el Cubit (no en `build`): así un
  /// cambio de membresía, moneda o tasa redibuja la vista aunque la lista de
  /// organizaciones no cambie.
  final Map<String, int> usuariosPorOrganizacion;
  final Map<String, String> monedaPorOrganizacion;
  final Map<String, TasaRegistro> tasaManualPorOrganizacion;

  const OrganizacionesState({
    this.status = OrganizacionesStatus.initial,
    this.organizaciones = const [],
    this.usuarios = const [],
    this.schemaMultiOrgListo = true,
    this.isRefreshing = false,
    this.expandedOrganizacionId,
    this.errorMessage,
    this.actionSuccessMessage,
    this.usuariosPorOrganizacion = const {},
    this.monedaPorOrganizacion = const {},
    this.tasaManualPorOrganizacion = const {},
  });

  OrganizacionesState copyWith({
    OrganizacionesStatus? status,
    List<Organizacion>? organizaciones,
    List<Usuario>? usuarios,
    bool? schemaMultiOrgListo,
    bool? isRefreshing,
    String? expandedOrganizacionId,
    bool clearExpandedId = false,
    String? errorMessage,
    String? actionSuccessMessage,
    Map<String, int>? usuariosPorOrganizacion,
    Map<String, String>? monedaPorOrganizacion,
    Map<String, TasaRegistro>? tasaManualPorOrganizacion,
  }) {
    return OrganizacionesState(
      status: status ?? this.status,
      organizaciones: organizaciones ?? this.organizaciones,
      usuarios: usuarios ?? this.usuarios,
      schemaMultiOrgListo: schemaMultiOrgListo ?? this.schemaMultiOrgListo,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      expandedOrganizacionId:
          clearExpandedId ? null : (expandedOrganizacionId ?? this.expandedOrganizacionId),
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      usuariosPorOrganizacion: usuariosPorOrganizacion ?? this.usuariosPorOrganizacion,
      monedaPorOrganizacion: monedaPorOrganizacion ?? this.monedaPorOrganizacion,
      tasaManualPorOrganizacion: tasaManualPorOrganizacion ?? this.tasaManualPorOrganizacion,
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
        expandedOrganizacionId,
        errorMessage,
        actionSuccessMessage,
        usuariosPorOrganizacion,
        monedaPorOrganizacion,
        tasaManualPorOrganizacion.map((k, t) => MapEntry(k, '${t.id}|${t.valor}')),
      ];
}
