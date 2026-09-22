import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/value_objects/money_usd.dart';
import 'package:estilo_neutral/core/value_objects/money_bs.dart';
import 'package:estilo_neutral/core/value_objects/exchange_rate.dart';
import 'package:estilo_neutral/core/value_objects/iso_date.dart';
import 'package:estilo_neutral/core/error/failures.dart';

void main() {
  group('Value Objects Tests', () {
    test('MoneyUsd redondea a 2 decimales y previene montos negativos', () {
      final m1 = MoneyUsd(19.999);
      expect(m1.value, 20.0);
      expect(() => MoneyUsd(-5.0), throwsA(isA<ValidationFailure>()));

      final m2 = MoneyUsd(10.50);
      final sum = m1 + m2;
      expect(sum.value, 30.50);

      final diff = m2 - m1;
      expect(diff.value, 0.0); // No negative money
    });

    test('MoneyBs valida rangos y formato', () {
      final bs = MoneyBs(9480.00);
      expect(bs.toFormattedString(), '9480.00');
      expect(() => MoneyBs(-1.0), throwsA(isA<ValidationFailure>()));
    });

    test('ExchangeRate realiza conversiones puras entre USD y Bs', () {
      final rate = ExchangeRate(474.00);
      final usd = MoneyUsd(20.00);
      final bs = rate.convertUsdToBs(usd);
      expect(bs.value, 9480.00);

      final backToUsd = rate.convertBsToUsd(bs);
      expect(backToUsd.value, 20.00);
    });

    test('IsoDate serializa estrictamente a YYYY-MM-DD', () {
      final date = IsoDate.fromString('2026-04-03');
      expect(date.toIso8601String(), '2026-04-03');
      expect(() => IsoDate.fromString('fecha_invalida'), throwsA(isA<ValidationFailure>()));
    });
  });
}
