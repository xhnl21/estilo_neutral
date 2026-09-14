import 'entity.dart';
import 'domain_event.dart';

/// Clase base para raíces de agregado (Aggregate Root)
abstract class AggregateRoot<TId> extends Entity<TId> {
  final List<DomainEvent> _domainEvents = [];

  AggregateRoot({required super.id});

  List<DomainEvent> get domainEvents => List.unmodifiable(_domainEvents);

  void addDomainEvent(DomainEvent event) {
    _domainEvents.add(event);
  }

  void clearDomainEvents() {
    _domainEvents.clear();
  }
}
