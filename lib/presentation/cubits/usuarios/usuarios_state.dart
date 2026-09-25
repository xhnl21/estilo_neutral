import 'package:equatable/equatable.dart';
import '../../../models/usuario.dart';

enum UsuariosStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Usuarios (BLoC/Cubit).
class UsuariosState extends Equatable {
  final UsuariosStatus status;
  final List<Usuario> usuarios;
  final List<Usuario> filteredUsuarios;
  final String searchQuery;
  final bool schemaMultiOrgListo;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const UsuariosState({
    this.status = UsuariosStatus.initial,
    this.usuarios = const [],
    this.filteredUsuarios = const [],
    this.searchQuery = '',
    this.schemaMultiOrgListo = true,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  UsuariosState copyWith({
    UsuariosStatus? status,
    List<Usuario>? usuarios,
    List<Usuario>? filteredUsuarios,
    String? searchQuery,
    bool? schemaMultiOrgListo,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return UsuariosState(
      status: status ?? this.status,
      usuarios: usuarios ?? this.usuarios,
      filteredUsuarios: filteredUsuarios ?? this.filteredUsuarios,
      searchQuery: searchQuery ?? this.searchQuery,
      schemaMultiOrgListo: schemaMultiOrgListo ?? this.schemaMultiOrgListo,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == UsuariosStatus.loading || status == UsuariosStatus.initial) &&
      usuarios.isEmpty;

  @override
  List<Object?> get props => [
        status,
        usuarios,
        filteredUsuarios,
        searchQuery,
        schemaMultiOrgListo,
        errorMessage,
        actionSuccessMessage,
      ];
}
