import '../../../../core/value_objects/entity_id.dart';

class CustomerId extends EntityId {
  const CustomerId._(super.value);

  factory CustomerId(String value) {
    EntityId.validate(value, 'c');
    return CustomerId._(value);
  }
}
