import '../types/value_object.dart';
import '../error/failures.dart';
import 'money_usd.dart';
import 'money_bs.dart';

/// Tasa de cambio cambiaria inmutable (BCV o Paralela)
class ExchangeRate extends ValueObject<double> {
  static const double minRate = 0.0001;
  static const double maxRate = 1e9;

  const ExchangeRate._(super.value);

  factory ExchangeRate(double rate) {
    if (rate < minRate || rate > maxRate) {
      throw ValidationFailure('La tasa de cambio ($rate) debe ser mayor a 0 y menor a 1e9.');
    }
    final rounded = double.parse(rate.toStringAsFixed(2));
    return ExchangeRate._(rounded);
  }

  /// Convierte un monto en USD a Bolívares usando la tasa
  MoneyBs convertUsdToBs(MoneyUsd usd) {
    return MoneyBs(usd.value * value);
  }

  /// Convierte un monto en Bolívares a USD usando la tasa
  MoneyUsd convertBsToUsd(MoneyBs bs) {
    if (value <= 0) return MoneyUsd.zero;
    return MoneyUsd(bs.value / value);
  }

  String toFormattedString() => value.toStringAsFixed(2);
}
