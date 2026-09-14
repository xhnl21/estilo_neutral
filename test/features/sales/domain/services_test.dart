import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/value_objects/money_usd.dart';
import 'package:estilo_neutral/core/value_objects/exchange_rate.dart';
import 'package:estilo_neutral/features/sales/domain/entities/product.dart';
import 'package:estilo_neutral/features/sales/domain/entities/sale_item.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/product_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/stock_quantity.dart';
import 'package:estilo_neutral/features/sales/domain/services/sale_calculator.dart';
import 'package:estilo_neutral/features/sales/domain/services/stock_validator.dart';

void main() {
  group('Domain Services Tests', () {
    test('SaleCalculator calcula subtotales y deudas con precisión matemática', () {
      const calc = SaleCalculator();
      final items = [
        SaleItem(
          id: '1',
          productId: ProductId('p00000001'),
          quantity: 2,
          unitPriceUsd: MoneyUsd(15.0),
        ),
        SaleItem(
          id: '2',
          productId: ProductId('p00000002'),
          quantity: 1,
          unitPriceUsd: MoneyUsd(25.0),
        ),
      ];

      final totalUsd = calc.calculateTotalUsd(items);
      expect(totalUsd.value, 55.0);

      final montoBs = calc.calculateMontoBs(totalUsd, ExchangeRate(474.0));
      expect(montoBs.value, 26070.0);

      final debt = calc.calculateDebt(totalUsd, MoneyUsd(50.0));
      expect(debt.value, 5.0);
    });

    test('StockValidator verifica disponibilidad de existencias', () {
      const validator = StockValidator();
      final product = Product(
        id: ProductId('p00000001'),
        stock: StockQuantity(3),
        name: 'Camisa',
        brand: 'Casual',
        model: 'Manga Larga',
        size: 'L',
        priceUsd: MoneyUsd(15.0),
      );

      expect(validator.canSell(product, 2), isTrue);
      expect(validator.canSell(product, 3), isTrue);
      expect(validator.canSell(product, 4), isFalse);
      expect(validator.canSell(product, -1), isFalse);
    });
  });
}
