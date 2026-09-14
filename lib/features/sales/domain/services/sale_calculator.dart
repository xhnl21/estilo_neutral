import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/money_bs.dart';
import '../../../../core/value_objects/exchange_rate.dart';
import '../entities/sale_item.dart';

/// Domain Service: SaleCalculator (puro, sin estado, 100% testeable)
class SaleCalculator {
  const SaleCalculator();

  MoneyUsd calculateTotalUsd(List<SaleItem> items) {
    double total = 0.0;
    for (final item in items) {
      total += item.subtotalUsd.value;
    }
    return MoneyUsd(total);
  }

  MoneyBs calculateMontoBs(MoneyUsd totalUsd, ExchangeRate bcvRate) {
    return bcvRate.convertUsdToBs(totalUsd);
  }

  MoneyUsd calculateDebt(MoneyUsd totalUsd, MoneyUsd paidAmount) {
    return totalUsd - paidAmount;
  }
}
