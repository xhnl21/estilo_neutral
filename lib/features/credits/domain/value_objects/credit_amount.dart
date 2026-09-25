import 'package:equatable/equatable.dart';

/// Value Object inmutable que representa un monto monetario en USD de crédito.
/// Invariante: debe ser estrictamente mayor que cero.
class CreditAmount extends Equatable {
  final double value;

  CreditAmount(double rawValue)
      : value = double.parse(rawValue.toStringAsFixed(2)) {
    if (value <= 0.0) {
      throw ArgumentError('CreditAmount debe ser estrictamente mayor a 0.00 USD (recibido: $value).');
    }
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value.toStringAsFixed(2);
}
