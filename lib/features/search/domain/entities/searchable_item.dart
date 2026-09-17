import 'package:equatable/equatable.dart';
import 'search_match.dart';

/// Contrato base abstracto para cualquier entidad indexable y evaluable
/// por el [SearchEngine].
abstract class SearchableItem extends Equatable {
  /// Identificador único de la entidad.
  final String id;

  /// Nombre o etiqueta principal visible de la entidad.
  final String name;

  /// Metadatos temporales resultantes del proceso de búsqueda y scoring.
  final SearchResult? searchResult;

  /// Constructor base para entidades buscables.
  const SearchableItem({
    required this.id,
    required this.name,
    this.searchResult,
  });

  /// Puntuación de búsqueda actual (0 si no ha sido evaluado).
  int get score => searchResult?.score ?? 0;

  /// Retorna una copia de la entidad con un nuevo [searchResult].
  SearchableItem copyWithSearchResult(SearchResult? result);

  @override
  List<Object?> get props => [id, name, searchResult];
}
