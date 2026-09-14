import '../../../../core/types/aggregate_root.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/money_bs.dart';
import '../../../../core/value_objects/exchange_rate.dart';
import '../../../../core/value_objects/iso_date.dart';
import '../../../../core/error/failures.dart';
import '../value_objects/sale_id.dart';
import '../value_objects/customer_id.dart';
import '../value_objects/payment_method.dart';
import '../value_objects/sale_status.dart';
import 'sale_item.dart';
import '../events/sales_events.dart';

/// Aggregate Root: Sale (Venta)
/// Invariantes:
/// - totalPagarUsd = sum(items.subtotal)
/// - deudaUsd = totalPagarUsd - abonoUsd
/// - abonoUsd >= 0 y <= totalPagarUsd
/// - estado = Pagada <=> deudaUsd == 0
class Sale extends AggregateRoot<SaleId> {
  final IsoDate _date;
  final CustomerId _customerId;
  final List<SaleItem> _items;
  final ExchangeRate _bcvRate;
  final ExchangeRate _usdRate;
  PaymentMethod _paymentMethod;
  final MoneyBs _mobilePaymentFeeBs;
  MoneyUsd _paidAmount;
  SaleStatus _status;

  Sale({
    required SaleId id,
    required IsoDate date,
    required CustomerId customerId,
    required List<SaleItem> items,
    required ExchangeRate bcvRate,
    required ExchangeRate usdRate,
    required PaymentMethod paymentMethod,
    required MoneyBs mobilePaymentFeeBs,
    required MoneyUsd paidAmount,
    required SaleStatus status,
  })  : _date = date,
        _customerId = customerId,
        _items = List.of(items),
        _bcvRate = bcvRate,
        _usdRate = usdRate,
        _paymentMethod = paymentMethod,
        _mobilePaymentFeeBs = mobilePaymentFeeBs,
        _paidAmount = paidAmount,
        _status = status,
        super(id: id) {
    _validateInvariants();
  }

  void _validateInvariants() {
    if (_items.isEmpty) {
      throw const ValidationFailure('Una venta debe contener al menos un producto.');
    }
    final total = totalPagarUsd;
    if (_paidAmount > total) {
      throw ValidationFailure(
        'El abono (${_paidAmount.toFormattedString()}) no puede exceder el total (${total.toFormattedString()}).',
      );
    }
    final debt = deudaUsd;
    if (debt.value == 0 && _status == SaleStatus.pending) {
      _status = SaleStatus.paid;
    }
  }

  IsoDate get date => _date;
  CustomerId get customerId => _customerId;
  List<SaleItem> get items => List.unmodifiable(_items);
  ExchangeRate get bcvRate => _bcvRate;
  ExchangeRate get usdRate => _usdRate;
  PaymentMethod get paymentMethod => _paymentMethod;
  MoneyBs get mobilePaymentFeeBs => _mobilePaymentFeeBs;
  MoneyUsd get paidAmount => _paidAmount;
  SaleStatus get status => _status;

  /// Invariante calculada: totalPagarUsd = sum(items.subtotal)
  MoneyUsd get totalPagarUsd {
    double sum = 0.0;
    for (final item in _items) {
      sum += item.subtotalUsd.value;
    }
    return MoneyUsd(sum);
  }

  /// Invariante calculada: montoBs = totalPagarUsd * bcvRate
  MoneyBs get montoBs => _bcvRate.convertUsdToBs(totalPagarUsd);

  /// Invariante calculada: deudaUsd = totalPagarUsd - paidAmount
  MoneyUsd get deudaUsd => totalPagarUsd - _paidAmount;

  void registerPayment(MoneyUsd payment, PaymentMethod method) {
    if (payment.value <= 0) return;
    final newPaid = _paidAmount + payment;
    if (newPaid > totalPagarUsd) {
      throw const ValidationFailure('El monto a abonar excede la deuda pendiente.');
    }
    _paidAmount = newPaid;
    _paymentMethod = method;

    if (deudaUsd.value == 0) {
      _status = SaleStatus.paid;
      addDomainEvent(
        SalePaid(
          eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
          occurredOn: DateTime.now().toUtc(),
          saleId: id.value,
          totalUsd: totalPagarUsd,
        ),
      );
    }
  }

  void cancel(String reason) {
    if (_status == SaleStatus.cancelled) return;
    _status = SaleStatus.cancelled;
    addDomainEvent(
      SaleCancelled(
        eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
        occurredOn: DateTime.now().toUtc(),
        saleId: id.value,
        reason: reason,
      ),
    );
  }
}
