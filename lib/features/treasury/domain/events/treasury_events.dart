import '../../../../core/types/domain_event.dart';
import '../../../../core/value_objects/money_usd.dart';

class CurrencyPurchaseCreated extends DomainEvent {
  final MoneyUsd capitalUsd;
  final String platform;

  CurrencyPurchaseCreated({
    required String eventId,
    required DateTime occurredOn,
    required String purchaseId,
    required this.capitalUsd,
    required this.platform,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: purchaseId,
          eventName: 'CurrencyPurchaseCreated',
        );
}

class CurrencyPurchaseCompleted extends DomainEvent {
  CurrencyPurchaseCompleted({
    required String eventId,
    required DateTime occurredOn,
    required String purchaseId,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: purchaseId,
          eventName: 'CurrencyPurchaseCompleted',
        );
}
