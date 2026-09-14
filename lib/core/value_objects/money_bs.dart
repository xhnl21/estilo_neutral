import '../types/value_object.dart';
import '../error/failures.dart';

/// Monto inmutable en Bolívares (VES / Bs)
class MoneyBs extends ValueObject<double> {
  static const double minAmount = 0.0;
  static const double maxAmount = 1e12;

  const MoneyBs._(super.value);

  factory MoneyBs(double amount) {
    if (amount < minAmount || amount > maxAmount) {
      throw ValidationFailure(
        'El monto en Bs ($amount) debe estar entre $minAmount y $maxAmount.',
      );
    }
    final rounded = double.parse(amount.toStringAsFixed(2));
    return MoneyBs._(rounded);
  }

  static const MoneyBs zero = MoneyBs._(0.0);

  MoneyBs operator +(MoneyBs other) => MoneyBs(value + other.value);
  MoneyBs operator -(MoneyBs other) {
    final result = value - other.value;
    if (result < 0) {
      return MoneyBs.zero;
    }
    return MoneyBs(result);
  }
  MoneyBs operator *(num factor) => MoneyBs(value * factor);

  bool operator >(MoneyBs other) => value > other.value;
  bool operator >=(MoneyBs other) => value >= other.value;
  bool operator <(MoneyBs other) => value < other.value;
  bool operator <=(MoneyBs other) => value <= other.value;

  String toFormattedString() => value.toStringAsFixed(2);
}
