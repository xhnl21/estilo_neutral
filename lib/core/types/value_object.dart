/// Clase base para todos los Value Objects DDD (inmutables y comparables por valor)
abstract class ValueObject<T> {
  final T value;

  const ValueObject(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueObject<T> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}
