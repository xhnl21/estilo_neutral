/// Clase base para eventos de dominio
abstract class DomainEvent {
  final String eventId;
  final DateTime occurredOn;
  final String aggregateId;
  final String eventName;

  DomainEvent({
    required this.eventId,
    required this.occurredOn,
    required this.aggregateId,
    required this.eventName,
  });

  @override
  String toString() => '$eventName(id: $eventId, aggId: $aggregateId, at: $occurredOn)';
}
