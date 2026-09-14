import '../../../../core/types/entity.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/error/failures.dart';
import '../value_objects/product_id.dart';

/// Entidad interna del Aggregate Sale: SaleItem
class SaleItem extends Entity<String> {
  final ProductId productId;
  final int quantity;
  final MoneyUsd unitPriceUsd;
  final MoneyUsd subtotalUsd;

  SaleItem({
    required super.id,
    required this.productId,
    required this.quantity,
    required this.unitPriceUsd,
  }) : subtotalUsd = MoneyUsd(unitPriceUsd.value * quantity) {
    if (quantity < 1) {
      throw const ValidationFailure('La cantidad de un ítem debe ser al menos 1.');
    }
  }
}
