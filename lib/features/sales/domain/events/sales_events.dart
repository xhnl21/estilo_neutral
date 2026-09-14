import '../../../../core/types/domain_event.dart';
import '../../../../core/value_objects/money_usd.dart';

class SaleCreated extends DomainEvent {
  final String customerId;
  final MoneyUsd totalUsd;
  final MoneyUsd paidAmount;

  SaleCreated({
    required String eventId,
    required DateTime occurredOn,
    required String saleId,
    required this.customerId,
    required this.totalUsd,
    required this.paidAmount,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: saleId,
          eventName: 'SaleCreated',
        );
}

class SalePaid extends DomainEvent {
  final MoneyUsd totalUsd;

  SalePaid({
    required String eventId,
    required DateTime occurredOn,
    required String saleId,
    required this.totalUsd,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: saleId,
          eventName: 'SalePaid',
        );
}

class SaleCancelled extends DomainEvent {
  final String reason;

  SaleCancelled({
    required String eventId,
    required DateTime occurredOn,
    required String saleId,
    required this.reason,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: saleId,
          eventName: 'SaleCancelled',
        );
}

class CustomerDebtIncreased extends DomainEvent {
  final MoneyUsd amountAdded;
  final MoneyUsd newBalance;

  CustomerDebtIncreased({
    required String eventId,
    required DateTime occurredOn,
    required String customerId,
    required this.amountAdded,
    required this.newBalance,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: customerId,
          eventName: 'CustomerDebtIncreased',
        );
}

class CustomerDebtCleared extends DomainEvent {
  CustomerDebtCleared({
    required String eventId,
    required DateTime occurredOn,
    required String customerId,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: customerId,
          eventName: 'CustomerDebtCleared',
        );
}

class StockDepleted extends DomainEvent {
  StockDepleted({
    required String eventId,
    required DateTime occurredOn,
    required String productId,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: productId,
          eventName: 'StockDepleted',
        );
}

class StockReplenished extends DomainEvent {
  final int newQuantity;

  StockReplenished({
    required String eventId,
    required DateTime occurredOn,
    required String productId,
    required this.newQuantity,
  }) : super(
          eventId: eventId,
          occurredOn: occurredOn,
          aggregateId: productId,
          eventName: 'StockReplenished',
        );
}
