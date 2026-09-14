import 'dart:async';
import '../types/domain_event.dart';

/// Bus de eventos en memoria (Publish/Subscribe) reactivo y sin polling
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _streamController = StreamController<DomainEvent>.broadcast();

  Stream<T> on<T extends DomainEvent>() {
    if (T == DomainEvent) {
      return _streamController.stream as Stream<T>;
    }
    return _streamController.stream.where((event) => event is T).cast<T>();
  }

  void publish(DomainEvent event) {
    if (!_streamController.isClosed) {
      _streamController.add(event);
    }
  }

  void dispose() {
    _streamController.close();
  }
}
