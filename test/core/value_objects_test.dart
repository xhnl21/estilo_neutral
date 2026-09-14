import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/value_objects/money_usd.dart';
import 'package:estilo_neutral/core/value_objects/money_bs.dart';
import 'package:estilo_neutral/core/value_objects/exchange_rate.dart';
import 'package:estilo_neutral/core/value_objects/iso_date.dart';
import 'package:estilo_neutral/core/error/failures.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/customer_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/product_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/sale_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/stock_quantity.dart';

void main() {
  group('Value Objects Tests', () {
    test('CustomerId valida formato regex y prefijo c', () {
      expect(() => CustomerId('c00000001'), returnsNormally);
      expect(() => CustomerId('invalid'), throwsA(isA<ValidationFailure>()));
      expect(() => CustomerId('p00000001'), throwsA(isA<ValidationFailure>()));
    });

    test('ProductId valida formato regex y prefijo p', () {
      expect(() => ProductId('p00000001'), returnsNormally);
      expect(() => ProductId('c00000001'), throwsA(isA<ValidationFailure>()));
    });

    test('SaleId valida formato regex y prefijo v', () {
      expect(() => SaleId('v00000001'), returnsNormally);
      expect(() => SaleId('x123'), throwsA(isA<ValidationFailure>()));
    });

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

    test('StockQuantity previene valores negativos', () {
      final stock = StockQuantity(10);
      final decremented = stock.decrement(4);
      expect(decremented.value, 6);
      expect(() => decremented.decrement(10), throwsA(isA<ValidationFailure>()));
    });
  });
}
