/// Estado del crédito de cliente según la norma ISO 8000.
enum CreditStatus {
  disponible,
  aplicado,
  anulado;

  String get toSheetValue {
    switch (this) {
      case CreditStatus.disponible:
        return 'DISPONIBLE';
      case CreditStatus.aplicado:
        return 'APLICADO';
      case CreditStatus.anulado:
        return 'ANULADO';
    }
  }

  static CreditStatus fromString(String? value) {
    switch (value?.trim().toUpperCase()) {
      case 'APLICADO':
        return CreditStatus.aplicado;
      case 'ANULADO':
        return CreditStatus.anulado;
      case 'DISPONIBLE':
      default:
        return CreditStatus.disponible;
    }
  }
}
