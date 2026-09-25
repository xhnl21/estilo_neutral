import 'package:equatable/equatable.dart';

/// Value Object inmutable que representa el identificador único de un crédito.
/// Cumple la regla de formato: ^cr\d{8}$ (ejemplo: cr00000001).
class CreditId extends Equatable {
  static final RegExp _regex = RegExp(r'^cr\d{8}$');

  final String value;

  CreditId(this.value) {
    if (!_regex.hasMatch(value)) {
      throw ArgumentError(
        'CreditId inválido: "$value". Debe coincidir con el formato ^cr\\d{8}\$ (ej: cr00000001).',
      );
    }
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
