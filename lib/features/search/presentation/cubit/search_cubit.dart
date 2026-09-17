import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/usecases/search_engine.dart';
import '../../domain/entities/searchable_item.dart';
import '../../domain/repositories/search_repository.dart';
import '../../infrastructure/utils/debouncer.dart';
import 'search_state.dart';

/// Cubit que administra el ciclo de vida del motor de búsqueda,
/// gestionando el debouncing, los estados de carga, resultados y vacíos.
class SearchCubit<T extends SearchableItem> extends Cubit<SearchState<T>> {
  final SearchEngine<T> _searchEngine;
  final SearchRepository<T> _repository;
  final Debouncer _debouncer;

  /// Crea una instancia del [SearchCubit].
  ///
  /// Opcionalmente permite inyectar un [Debouncer] personalizado (útil para pruebas).
  SearchCubit({
    required SearchEngine<T> searchEngine,
    required SearchRepository<T> repository,
    Debouncer? debouncer,
  })  : _searchEngine = searchEngine,
        _repository = repository,
        _debouncer = debouncer ?? Debouncer(duration: const Duration(milliseconds: 300)),
        super(SearchInitial<T>(query: '', items: repository.getItems()));

  /// Notifica un cambio en el texto de búsqueda proveniente del TextField.
  ///
  /// Aplica automáticamente el debounce de 300ms antes de ejecutar el cómputo.
  void onQueryChanged(String query) {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _debouncer.cancel();
      emit(SearchInitial<T>(query: '', items: _repository.getItems()));
      return;
    }

    // Emitir estado de carga preliminar preservando los items actuales
    emit(SearchLoading<T>(query: trimmed, items: state.items));

    _debouncer.run(() {
      _executeSearch(trimmed);
    });
  }

  /// Ejecuta la búsqueda de forma inmediata sin esperar el debounce
  /// (por ejemplo, al presionar 'Enter' o la acción de búsqueda en el teclado).
  void searchImmediately(String query) {
    _debouncer.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      emit(SearchInitial<T>(query: '', items: _repository.getItems()));
      return;
    }

    emit(SearchLoading<T>(query: trimmed, items: state.items));
    _executeSearch(trimmed);
  }

  /// Limpia la consulta actual y restaura el catálogo completo en estado inicial.
  void clear() {
    _debouncer.cancel();
    emit(SearchInitial<T>(query: '', items: _repository.getItems()));
  }

  void _executeSearch(String query) {
    try {
      final results = _searchEngine.searchFromRepository(
        repository: _repository,
        query: query,
      );

      if (isClosed) return;

      if (results.isEmpty) {
        emit(SearchEmpty<T>(query: query));
      } else {
        emit(SearchLoaded<T>(query: query, items: results));
      }
    } catch (e) {
      if (isClosed) return;
      emit(SearchError<T>(
        query: query,
        message: 'Error al ejecutar la búsqueda: $e',
        items: state.items,
      ));
    }
  }

  @override
  Future<void> close() {
    _debouncer.dispose();
    return super.close();
  }
}
