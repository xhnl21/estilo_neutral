import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/value_objects/money_usd.dart';
import 'package:estilo_neutral/core/value_objects/money_bs.dart';
import 'package:estilo_neutral/core/value_objects/exchange_rate.dart';
import 'package:estilo_neutral/core/value_objects/iso_date.dart';
import 'package:estilo_neutral/core/error/failures.dart';
import 'package:estilo_neutral/features/sales/domain/entities/customer.dart';
import 'package:estilo_neutral/features/sales/domain/entities/product.dart';
import 'package:estilo_neutral/features/sales/domain/entities/sale.dart';
import 'package:estilo_neutral/features/sales/domain/entities/sale_item.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/customer_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/product_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/sale_id.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/stock_quantity.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/payment_method.dart';
import 'package:estilo_neutral/features/sales/domain/value_objects/sale_status.dart';

void main() {
  group('Aggregates Domain Tests', () {
    test('Customer Aggregate protege invariantes E.164 y email', () {
      final customer = Customer(
        id: CustomerId('c00000001'),
        name: 'Neida',
        phone: '+584120000001',
        email: 'neida.cliente@ejemplo.com',
        debtBalance: MoneyUsd.zero,
        registeredAt: IsoDate.fromString('2026-04-03'),
      );

      expect(customer.name, 'Neida');
      expect(customer.debtBalance.value, 0.0);

      customer.increaseDebt(MoneyUsd(50.0));
      expect(customer.debtBalance.value, 50.0);
      expect(customer.domainEvents.length, 1);

      customer.payDebt(MoneyUsd(50.0));
      expect(customer.debtBalance.value, 0.0);
      expect(customer.domainEvents.length, 2); // CustomerDebtCleared emitted
    });

    test('Customer lanza ValidationFailure ante teléfono inválido', () {
      expect(
        () => Customer(
          id: CustomerId('c00000001'),
          name: 'Neida',
          phone: '04121234567', // Falta +58
          email: 'neida@mail.com',
          debtBalance: MoneyUsd.zero,
          registeredAt: IsoDate.now(),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Product Aggregate gestiona stock y emite StockDepleted', () {
      final product = Product(
        id: ProductId('p00000001'),
        stock: StockQuantity(5),
        name: 'Pantalon',
        brand: 'Generica',
        model: 'Casual',
        size: 'M',
        priceUsd: MoneyUsd(20.0),
      );

      product.decrementStock(5);
      expect(product.stock.value, 0);
      expect(product.domainEvents.length, 1); // StockDepleted

      product.replenishStock(10);
      expect(product.stock.value, 10);
      expect(product.domainEvents.length, 2); // StockReplenished
    });

    test('Sale Aggregate calcula totales, deudas y actualiza estado', () {
      final item = SaleItem(
        id: 'item_1',
        productId: ProductId('p00000001'),
        quantity: 2,
        unitPriceUsd: MoneyUsd(20.0),
      );

      final sale = Sale(
        id: SaleId('v00000001'),
        date: IsoDate.fromString('2026-04-03'),
        customerId: CustomerId('c00000001'),
        items: [item],
        bcvRate: ExchangeRate(474.00),
        usdRate: ExchangeRate(800.00),
        paymentMethod: PaymentMethod.cash,
        mobilePaymentFeeBs: MoneyBs.zero,
        paidAmount: MoneyUsd(10.0), // Abono parcial
        status: SaleStatus.pending,
      );

      expect(sale.totalPagarUsd.value, 40.0); // 2 * 20.0
      expect(sale.deudaUsd.value, 30.0); // 40.0 - 10.0
      expect(sale.montoBs.value, 18960.0); // 40.0 * 474.0
      expect(sale.status, SaleStatus.pending);

      // Abonar el resto
      sale.registerPayment(MoneyUsd(30.0), PaymentMethod.cash);
      expect(sale.deudaUsd.value, 0.0);
      expect(sale.status, SaleStatus.paid);
      expect(sale.domainEvents.length, 1); // SalePaid emitted
    });
  });
}
