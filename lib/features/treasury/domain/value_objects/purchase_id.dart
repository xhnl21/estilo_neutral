import '../../../../core/value_objects/entity_id.dart';

class PurchaseId extends EntityId {
  const PurchaseId._(super.value);

  factory PurchaseId(String value) {
    EntityId.validate(value, 'd');
    return PurchaseId._(value);
  }
}
