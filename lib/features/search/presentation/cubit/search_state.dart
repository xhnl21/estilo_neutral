import 'package:equatable/equatable.dart';
import '../../domain/entities/searchable_item.dart';

/// Clase base para los estados del buscador reactivo.
sealed class SearchState<T extends SearchableItem> extends Equatable {
  /// Consulta actual enviada por el usuario.
  final String query;

  /// Lista actual de elementos visibles.
  final List<T> items;

  const SearchState({
    required this.query,
    this.items = const [],
  });

  /// Indica si el estado representa una búsqueda activa en proceso.
  bool get isLoading => false;

  /// Indica si el estado representa cero resultados tras una consulta no vacía.
  bool get isEmpty => false;

  @override
  List<Object?> get props => [query, items];
}

/// Estado inicial cuando el campo de búsqueda está vacío o recién instanciado.
class SearchInitial<T extends SearchableItem> extends SearchState<T> {
  const SearchInitial({super.query = '', super.items = const []});
}

/// Estado de carga mientras el motor procesa el query con debounce.
class SearchLoading<T extends SearchableItem> extends SearchState<T> {
  const SearchLoading({required super.query, super.items = const []});

  @override
  bool get isLoading => true;
}

/// Estado con resultados coincidentes (score > 0).
class SearchLoaded<T extends SearchableItem> extends SearchState<T> {
  const SearchLoaded({required super.query, required super.items});
}

/// Estado vacío cuando la consulta no arrojó ninguna coincidencia.
class SearchEmpty<T extends SearchableItem> extends SearchState<T> {
  const SearchEmpty({required super.query}) : super(items: const []);

  @override
  bool get isEmpty => true;
}

/// Estado de error ante fallas inesperadas durante la búsqueda.
class SearchError<T extends SearchableItem> extends SearchState<T> {
  final String message;

  const SearchError({
    required super.query,
    required this.message,
    super.items = const [],
  });

  @override
  List<Object?> get props => [query, items, message];
}
