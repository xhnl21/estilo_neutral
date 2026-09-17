import 'package:estilo_neutral/features/search/infrastructure/algorithms/scattered_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScatteredMatch', () {
    test('matches letters scattered in sequential order', () {
      expect(ScatteredMatch.isMatch('bva', 'bbva'), isTrue);
      expect(ScatteredMatch.isMatch('bdv', 'banco de venezuela'), isTrue);
      expect(ScatteredMatch.isMatch('bnc', 'banco nacional de credito'), isTrue);
    });

    test('fails when characters are out of order or missing', () {
      expect(ScatteredMatch.isMatch('avb', 'bbva'), isFalse);
      expect(ScatteredMatch.isMatch('xyz', 'banco provincial'), isFalse);
      expect(ScatteredMatch.isMatch('banesquito', 'banesco'), isFalse);
    });

    test('findMatchIndices returns exact positions of scattered letters', () {
      final indices = ScatteredMatch.findMatchIndices('bdv', 'banco de venezuela');
      expect(indices, isNotNull);
      expect(indices!.length, equals(3));
      expect(indices[0], equals(0)); // 'b' en 'banco'
      expect(indices[1], equals(6)); // 'd' en 'de'
      expect(indices[2], equals(9)); // 'v' en 'venezuela'
    });

    test('findMatchIndices returns empty list for empty pattern', () {
      expect(ScatteredMatch.findMatchIndices('', 'test'), isEmpty);
    });

    test('findMatchIndices returns null for non-matching pattern', () {
      expect(ScatteredMatch.findMatchIndices('zzz', 'bancaribe'), isNull);
    });
  });
}
