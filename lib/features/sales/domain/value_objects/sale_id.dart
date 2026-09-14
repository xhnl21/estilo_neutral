import '../../../../core/value_objects/entity_id.dart';

class SaleId extends EntityId {
  const SaleId._(super.value);

  factory SaleId(String value) {
    EntityId.validate(value, 'v');
    return SaleId._(value);
  }
}
