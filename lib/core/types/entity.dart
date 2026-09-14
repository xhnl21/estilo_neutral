/// Clase base para todas las Entidades DDD
abstract class Entity<TId> {
  final TId id;

  const Entity({required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity<TId> && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
