import '../../../../core/types/domain_event.dart';
import '../../../../core/value_objects/money_usd.dart';

class CurrencyPurchaseCreated extends DomainEvent {
  final MoneyUsd capitalUsd;
  final String platform;

  CurrencyPurchaseCreated({
    required super.eventId,
    required super.occurredOn,
    required String purchaseId,
    required this.capitalUsd,
    required this.platform,
  }) : super(
          aggregateId: purchaseId,
          eventName: 'CurrencyPurchaseCreated',
        );
}

class CurrencyPurchaseCompleted extends DomainEvent {
  CurrencyPurchaseCompleted({
    required super.eventId,
    required super.occurredOn,
    required String purchaseId,
  }) : super(
          aggregateId: purchaseId,
          eventName: 'CurrencyPurchaseCompleted',
        );
}
