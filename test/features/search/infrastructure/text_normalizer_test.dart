import 'package:estilo_neutral/features/search/infrastructure/utils/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextNormalizer', () {
    test('normalizes uppercase and diacritics to lowercase ASCII', () {
      expect(TextNormalizer.normalize('Álvaro Pérez'), equals('alvaro perez'));
      expect(TextNormalizer.normalize('BANCO MERCANTIL'), equals('banco mercantil'));
      expect(TextNormalizer.normalize('Crédito & Inversión'), equals('credito & inversion'));
      expect(TextNormalizer.normalize('Caroní y Cañon'), equals('caroni y canon'));
    });

    test('handles null, empty string and whitespace', () {
      expect(TextNormalizer.normalize(null), equals(''));
      expect(TextNormalizer.normalize(''), equals(''));
      expect(TextNormalizer.normalize('   '), equals('   '));
    });

    test('tokenize splits words and ignores multiple spaces', () {
      expect(
        TextNormalizer.tokenize('  Banco   de   Venezuela  '),
        equals(['banco', 'de', 'venezuela']),
      );
      expect(TextNormalizer.tokenize(null), isEmpty);
      expect(TextNormalizer.tokenize(''), isEmpty);
    });
  });
}
