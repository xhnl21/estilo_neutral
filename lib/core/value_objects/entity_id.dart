import '../types/value_object.dart';
import '../error/failures.dart';

/// Identificador de entidad genérico validado con regex ^[a-z]\d{8}$
abstract class EntityId extends ValueObject<String> {
  static final RegExp _regex = RegExp(r'^[a-z]\d{8}$');

  const EntityId(super.value);

  static void validate(String value, String prefix) {
    if (!_regex.hasMatch(value)) {
      throw ValidationFailure(
        'El ID "$value" no cumple con el formato estándar regex ^[a-z]\\d{8}\$',
      );
    }
    if (!value.startsWith(prefix)) {
      throw ValidationFailure(
        'El ID "$value" debe iniciar con el prefijo "$prefix"',
      );
    }
  }
}
