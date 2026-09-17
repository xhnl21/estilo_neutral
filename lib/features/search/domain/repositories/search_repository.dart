import '../entities/searchable_item.dart';

/// Contrato abstracto del repositorio de búsqueda para entidades [T].
abstract interface class SearchRepository<T extends SearchableItem> {
  /// Retorna la lista de entidades disponibles para búsqueda en memoria.
  List<T> getItems();

  /// Retorna un diccionario con sinónimos o palabras clave ocultas indexadas por id o código.
  /// Ejemplo: `{'0108': 'bbva provincial', '0102': 'bdv banco de venezuela'}`.
  Map<String, String> getSynonyms();
}
