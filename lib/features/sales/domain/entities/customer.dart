import '../../../../core/types/aggregate_root.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/iso_date.dart';
import '../../../../core/error/failures.dart';
import '../value_objects/customer_id.dart';
import '../events/sales_events.dart';

/// Aggregate Root: Customer (Cliente)
/// Invariantes: saldoDeudaUsd >= 0, telefono E.164, email válido
class Customer extends AggregateRoot<CustomerId> {
  final String _name;
  String _phone;
  String _email;
  MoneyUsd _debtBalance;
  final IsoDate _registeredAt;

  static final RegExp _phoneRegex = RegExp(r'^\+58\d{10}$');
  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  Customer({
    required super.id,
    required String name,
    required String phone,
    required String email,
    required MoneyUsd debtBalance,
    required IsoDate registeredAt,
  })  : _name = name,
        _phone = phone,
        _email = email,
        _debtBalance = debtBalance,
        _registeredAt = registeredAt {
    _validate();
  }

  void _validate() {
    if (_name.trim().isEmpty) {
      throw const ValidationFailure('El nombre del cliente no puede estar vacío.');
    }
    if (!_phoneRegex.hasMatch(_phone.trim())) {
      throw ValidationFailure(
        'El teléfono "$_phone" no cumple con el formato internacional E.164 (+58...).',
      );
    }
    if (!_emailRegex.hasMatch(_email.trim())) {
      throw ValidationFailure(
        'El correo electrónico "$_email" no tiene un formato válido RFC 5322.',
      );
    }
  }

  String get name => _name;
  String get phone => _phone;
  String get email => _email;
  MoneyUsd get debtBalance => _debtBalance;
  IsoDate get registeredAt => _registeredAt;

  void increaseDebt(MoneyUsd amount) {
    if (amount.value <= 0) return;
    _debtBalance = _debtBalance + amount;
    addDomainEvent(
      CustomerDebtIncreased(
        eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
        occurredOn: DateTime.now().toUtc(),
        customerId: id.value,
        amountAdded: amount,
        newBalance: _debtBalance,
      ),
    );
  }

  void payDebt(MoneyUsd amount) {
    if (amount.value <= 0) return;
    final previous = _debtBalance;
    _debtBalance = _debtBalance - amount;

    if (previous.value > 0 && _debtBalance.value == 0) {
      addDomainEvent(
        CustomerDebtCleared(
          eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
          occurredOn: DateTime.now().toUtc(),
          customerId: id.value,
        ),
      );
    }
  }

  void updateContact({required String phone, required String email}) {
    _phone = phone;
    _email = email;
    _validate();
  }
}
