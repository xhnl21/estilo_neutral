import '../../../../core/types/domain_event.dart';
import '../../../../core/value_objects/money_usd.dart';

class SaleCreated extends DomainEvent {
  final String customerId;
  final MoneyUsd totalUsd;
  final MoneyUsd paidAmount;

  SaleCreated({
    required super.eventId,
    required super.occurredOn,
    required String saleId,
    required this.customerId,
    required this.totalUsd,
    required this.paidAmount,
  }) : super(
          aggregateId: saleId,
          eventName: 'SaleCreated',
        );
}

class SalePaid extends DomainEvent {
  final MoneyUsd totalUsd;

  SalePaid({
    required super.eventId,
    required super.occurredOn,
    required String saleId,
    required this.totalUsd,
  }) : super(
          aggregateId: saleId,
          eventName: 'SalePaid',
        );
}

class SaleCancelled extends DomainEvent {
  final String reason;

  SaleCancelled({
    required super.eventId,
    required super.occurredOn,
    required String saleId,
    required this.reason,
  }) : super(
          aggregateId: saleId,
          eventName: 'SaleCancelled',
        );
}

class CustomerDebtIncreased extends DomainEvent {
  final MoneyUsd amountAdded;
  final MoneyUsd newBalance;

  CustomerDebtIncreased({
    required super.eventId,
    required super.occurredOn,
    required String customerId,
    required this.amountAdded,
    required this.newBalance,
  }) : super(
          aggregateId: customerId,
          eventName: 'CustomerDebtIncreased',
        );
}

class CustomerDebtCleared extends DomainEvent {
  CustomerDebtCleared({
    required super.eventId,
    required super.occurredOn,
    required String customerId,
  }) : super(
          aggregateId: customerId,
          eventName: 'CustomerDebtCleared',
        );
}

class StockDepleted extends DomainEvent {
  StockDepleted({
    required super.eventId,
    required super.occurredOn,
    required String productId,
  }) : super(
          aggregateId: productId,
          eventName: 'StockDepleted',
        );
}

class StockReplenished extends DomainEvent {
  final int newQuantity;

  StockReplenished({
    required super.eventId,
    required super.occurredOn,
    required String productId,
    required this.newQuantity,
  }) : super(
          aggregateId: productId,
          eventName: 'StockReplenished',
        );
}
