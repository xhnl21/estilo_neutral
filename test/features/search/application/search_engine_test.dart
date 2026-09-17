import 'package:estilo_neutral/features/search/application/usecases/search_engine.dart';
import 'package:estilo_neutral/features/search/domain/entities/inventario_item.dart';
import 'package:estilo_neutral/features/search/infrastructure/repositories/cloud_inventario_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchEngine con datos de Inventario', () {
    late CloudInventarioSearchRepository repository;
    late SearchEngine<InventarioItem> searchEngine;

    setUp(() {
      repository = CloudInventarioSearchRepository();
      searchEngine = SearchEngine<InventarioItem>();
    });

    test('returns empty list when query is empty or whitespace', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: '   ',
      );
      expect(results, isEmpty);
    });

    test('cleans stop words and finds product by item name', () {
      // 'de' es stop word en español, por lo que evalúa 'camisa' y 'oxford'
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'camisa de oxford',
      );

      expect(results, isNotEmpty);
      expect(results.first.id, equals('p00000001'));
      expect(results.first.score, greaterThanOrEqualTo(100));
    });

    test('finds product by product ID (p00000003 -> Franela Nike)', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'p00000003',
      );

      expect(results, isNotEmpty);
      expect(results.first.id, equals('p00000003'));
      expect(results.first.marca, equals('Nike'));
    });

    test('finds product by brand / hidden synonyms (ej. nike, levis)', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'nike',
      );

      expect(results, isNotEmpty);
      expect(results.first.marca, equals('Nike'));
      expect(results.first.id, equals('p00000003'));
    });

    test('scores perfect match with 100 points', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'chaqueta',
      );

      expect(results, isNotEmpty);
      expect(results.first.id, equals('p00000004'));
      expect(results.first.score, greaterThanOrEqualTo(100));
    });

    test('scores fuzzy match with typo (pantalon jian -> Pantalón Jean 501)', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'jian',
      );

      expect(results, isNotEmpty);
      expect(results.first.id, equals('p00000002'));
      // Levenshtein 'jian' vs 'jean' = 1 dist: 80 - 15 = 65 pts
      expect(results.first.score, equals(65));
    });

    test('scores scattered match (nke -> nike)', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'nke',
      );

      expect(results, isNotEmpty);
      expect(results.any((p) => p.id == 'p00000003'), isTrue);
    });

    test('excludes items with score 0 and sorts descending by score', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'columbia',
      );

      expect(results, isNotEmpty);
      expect(results.first.id, equals('p00000004'));

      for (var i = 0; i < results.length - 1; i++) {
        expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
        expect(results[i].score, greaterThan(0));
      }
    });

    test('populates highlightSpans on matching product names', () {
      final results = searchEngine.searchFromRepository(
        repository: repository,
        query: 'bermuda',
      );

      expect(results, isNotEmpty);
      final item = results.firstWhere((p) => p.id == 'p00000008');
      final spans = item.searchResult?.highlightSpans;

      expect(spans, isNotNull);
      expect(spans, isNotEmpty);
      expect(
        item.name.substring(spans!.first.start, spans.first.end).toLowerCase(),
        equals('bermuda'),
      );
    });
  });
}
