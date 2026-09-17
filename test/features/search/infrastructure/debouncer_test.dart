import 'package:estilo_neutral/features/search/infrastructure/utils/debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debouncer', () {
    test('executes action only after specified duration', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
      var executedCount = 0;

      debouncer.run(() {
        executedCount++;
      });

      expect(executedCount, equals(0));
      expect(debouncer.isActive, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(executedCount, equals(1));
      expect(debouncer.isActive, isFalse);

      debouncer.dispose();
    });

    test('cancels previous pending execution if triggered repeatedly', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
      var lastValue = '';

      debouncer.run(() => lastValue = 'first');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      debouncer.run(() => lastValue = 'second');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      debouncer.run(() => lastValue = 'third');
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(lastValue, equals('third'));

      debouncer.dispose();
    });

    test('cancel aborts execution', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
      var executed = false;

      debouncer.run(() => executed = true);
      debouncer.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(executed, isFalse);
      expect(debouncer.isActive, isFalse);

      debouncer.dispose();
    });
  });
}
