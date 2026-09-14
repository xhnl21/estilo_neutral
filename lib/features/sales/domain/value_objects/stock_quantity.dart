import '../../../../core/types/value_object.dart';
import '../../../../core/error/failures.dart';

/// Cantidad física en inventario (>= 0)
class StockQuantity extends ValueObject<int> {
  const StockQuantity._(super.value);

  factory StockQuantity(int quantity) {
    if (quantity < 0) {
      throw const ValidationFailure('La cantidad en inventario no puede ser negativa.');
    }
    return StockQuantity._(quantity);
  }

  static const StockQuantity zero = StockQuantity._(0);

  StockQuantity increment(int amount) {
    if (amount <= 0) return this;
    return StockQuantity(value + amount);
  }

  StockQuantity decrement(int amount) {
    if (amount <= 0) return this;
    final remaining = value - amount;
    if (remaining < 0) {
      throw const ValidationFailure('Stock insuficiente para la operación.');
    }
    return StockQuantity(remaining);
  }
}
