import '../../../../core/value_objects/entity_id.dart';

class ProductId extends EntityId {
  const ProductId._(super.value);

  factory ProductId(String value) {
    EntityId.validate(value, 'p');
    return ProductId._(value);
  }
}
