/// Método de pago sellado según lenguaje ubicuo
enum PaymentMethod {
  cash('Efectivo'),
  mobilePayment('Pago Movil'),
  bankTransfer('Transferencia'),
  zelle('Zelle'),
  binance('Binance'),
  other('Otro');

  final String sheetValue;
  const PaymentMethod(this.sheetValue);

  static PaymentMethod fromSheetValue(String value) {
    for (final method in PaymentMethod.values) {
      if (method.sheetValue.toLowerCase() == value.trim().toLowerCase()) {
        return method;
      }
    }
    return PaymentMethod.other;
  }
}
