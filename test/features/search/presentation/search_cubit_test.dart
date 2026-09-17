import 'package:estilo_neutral/features/search/application/usecases/search_engine.dart';
import 'package:estilo_neutral/features/search/domain/entities/inventario_item.dart';
import 'package:estilo_neutral/features/search/infrastructure/repositories/cloud_inventario_search_repository.dart';
import 'package:estilo_neutral/features/search/infrastructure/utils/debouncer.dart';
import 'package:estilo_neutral/features/search/presentation/cubit/search_cubit.dart';
import 'package:estilo_neutral/features/search/presentation/cubit/search_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchCubit con Inventario', () {
    late CloudInventarioSearchRepository repository;
    late SearchEngine<InventarioItem> searchEngine;
    late SearchCubit<InventarioItem> cubit;

    setUp(() {
      repository = CloudInventarioSearchRepository();
      searchEngine = SearchEngine<InventarioItem>();
      cubit = SearchCubit<InventarioItem>(
        searchEngine: searchEngine,
        repository: repository,
        debouncer: Debouncer(duration: const Duration(milliseconds: 10)),
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has all inventory items in SearchInitial', () {
      expect(cubit.state, isA<SearchInitial<InventarioItem>>());
      expect(cubit.state.items.length, equals(repository.getItems().length));
      expect(cubit.state.query, isEmpty);
    });

    test('searchImmediately emits SearchLoading then SearchLoaded for inventario', () {
      cubit.searchImmediately('nike');

      expect(cubit.state, isA<SearchLoaded<InventarioItem>>());
      expect(cubit.state.items, isNotEmpty);
      expect(cubit.state.items.first.marca, equals('Nike'));
    });

    test('searchImmediately for unknown query emits SearchEmpty', () {
      cubit.searchImmediately('producto_inexistente_xyz_999');

      expect(cubit.state, isA<SearchEmpty<InventarioItem>>());
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
    });

    test('onQueryChanged debounces and executes search on inventory', () async {
      cubit.onQueryChanged('jian');

      expect(cubit.state, isA<SearchLoading<InventarioItem>>());

      // Esperar que el debouncer (10ms) dispare
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(cubit.state, isA<SearchLoaded<InventarioItem>>());
      expect(cubit.state.items.first.id, equals('p00000002'));
    });

    test('onQueryChanged with empty query resets to SearchInitial', () async {
      cubit.searchImmediately('zara');
      expect(cubit.state, isA<SearchLoaded<InventarioItem>>());

      cubit.onQueryChanged('');
      expect(cubit.state, isA<SearchInitial<InventarioItem>>());
      expect(cubit.state.items.length, equals(repository.getItems().length));
    });

    test('clear resets query and items', () {
      cubit.searchImmediately('adidas');
      expect(cubit.state, isA<SearchLoaded<InventarioItem>>());

      cubit.clear();
      expect(cubit.state, isA<SearchInitial<InventarioItem>>());
      expect(cubit.state.items.length, equals(repository.getItems().length));
    });
  });
}
