import '../types/value_object.dart';
import '../error/failures.dart';

/// Monto inmutable en Dólares Estadounidenses (USD)
class MoneyUsd extends ValueObject<double> {
  static const double minAmount = 0.0;
  static const double maxAmount = 1e9;

  const MoneyUsd._(super.value);

  factory MoneyUsd(double amount) {
    if (amount < minAmount || amount > maxAmount) {
      throw ValidationFailure(
        'El monto en USD ($amount) debe estar entre $minAmount y $maxAmount.',
      );
    }
    // Redondeo exacto a 2 decimales
    final rounded = double.parse(amount.toStringAsFixed(2));
    return MoneyUsd._(rounded);
  }

  static const MoneyUsd zero = MoneyUsd._(0.0);

  MoneyUsd operator +(MoneyUsd other) => MoneyUsd(value + other.value);
  MoneyUsd operator -(MoneyUsd other) {
    final result = value - other.value;
    if (result < 0) {
      return MoneyUsd.zero;
    }
    return MoneyUsd(result);
  }
  MoneyUsd operator *(num factor) => MoneyUsd(value * factor);

  bool operator >(MoneyUsd other) => value > other.value;
  bool operator >=(MoneyUsd other) => value >= other.value;
  bool operator <(MoneyUsd other) => value < other.value;
  bool operator <=(MoneyUsd other) => value <= other.value;

  String toFormattedString() => value.toStringAsFixed(2);
}
