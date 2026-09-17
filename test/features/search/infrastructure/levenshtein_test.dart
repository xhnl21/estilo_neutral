import 'package:estilo_neutral/features/search/infrastructure/algorithms/levenshtein.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Levenshtein', () {
    test('computes exact match as distance 0', () {
      expect(Levenshtein.distance('bbva', 'bbva'), equals(0));
      expect(Levenshtein.similarity('bbva', 'bbva'), equals(1.0));
    });

    test('computes empty string distances', () {
      expect(Levenshtein.distance('', 'banesco'), equals(7));
      expect(Levenshtein.distance('mercantil', ''), equals(9));
      expect(Levenshtein.distance('', ''), equals(0));
    });

    test('computes single edit operations correctly', () {
      // Sustitución
      expect(Levenshtein.distance('provinsial', 'provincial'), equals(1));
      // Inserción
      expect(Levenshtein.distance('banes', 'baneso'), equals(1));
      // Eliminación
      expect(Levenshtein.distance('bancaribee', 'bancaribe'), equals(1));
    });

    test('computes distance 2', () {
      expect(Levenshtein.distance('vnesuela', 'venezuela'), equals(2));
    });

    test('similarity is between 0.0 and 1.0', () {
      final sim = Levenshtein.similarity('banesco', 'banesko');
      expect(sim, closeTo(6 / 7, 0.01));
    });
  });
}
