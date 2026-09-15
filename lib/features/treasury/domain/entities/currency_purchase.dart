import '../../../../core/types/aggregate_root.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/exchange_rate.dart';
import '../../../../core/value_objects/iso_date.dart';
import '../../../../core/error/failures.dart';
import '../value_objects/purchase_id.dart';
import '../events/treasury_events.dart';

/// Aggregate Root: CurrencyPurchase (Compra de Divisas)
/// Invariantes: deliveryDate >= purchaseDate, capitalUsd > 0, platformFeeUsd >= 0
class CurrencyPurchase extends AggregateRoot<PurchaseId> {
  final IsoDate _purchaseDate;
  final IsoDate _deliveryDate;
  final MoneyUsd _capitalUsd;
  final MoneyUsd _platformFeeUsd;
  final String _orderNumber;
  final String _platform;
  final String _seller;
  final ExchangeRate _bcvRate;
  final ExchangeRate _usdRate;

  CurrencyPurchase({
    required super.id,
    required IsoDate purchaseDate,
    required IsoDate deliveryDate,
    required MoneyUsd capitalUsd,
    required MoneyUsd platformFeeUsd,
    required String orderNumber,
    required String platform,
    required String seller,
    required ExchangeRate bcvRate,
    required ExchangeRate usdRate,
  })  : _purchaseDate = purchaseDate,
        _deliveryDate = deliveryDate,
        _capitalUsd = capitalUsd,
        _platformFeeUsd = platformFeeUsd,
        _orderNumber = orderNumber,
        _platform = platform,
        _seller = seller,
        _bcvRate = bcvRate,
        _usdRate = usdRate {
    if (_deliveryDate.isBefore(_purchaseDate)) {
      throw const ValidationFailure('La fecha de entrega no puede ser anterior a la fecha de compra.');
    }
    if (_capitalUsd.value <= 0) {
      throw const ValidationFailure('El capital adquirido en USD debe ser mayor a 0.');
    }
  }

  IsoDate get purchaseDate => _purchaseDate;
  IsoDate get deliveryDate => _deliveryDate;
  MoneyUsd get capitalUsd => _capitalUsd;
  MoneyUsd get platformFeeUsd => _platformFeeUsd;
  String get orderNumber => _orderNumber;
  String get platform => _platform;
  String get seller => _seller;
  ExchangeRate get bcvRate => _bcvRate;
  ExchangeRate get usdRate => _usdRate;

  void complete() {
    addDomainEvent(
      CurrencyPurchaseCompleted(
        eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
        occurredOn: DateTime.now().toUtc(),
        purchaseId: id.value,
      ),
    );
  }
}
