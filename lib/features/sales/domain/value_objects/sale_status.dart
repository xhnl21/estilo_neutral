/// Estado del ciclo de vida de una venta (Fase 10.A.6 / Fase 11)
enum SaleStatus {
  pending('Pendiente'),
  paid('Pagada'),
  cancelled('Anulada'),
  quarantined('Cuarentena');

  final String sheetValue;
  const SaleStatus(this.sheetValue);

  static SaleStatus fromSheetValue(String value) {
    for (final status in SaleStatus.values) {
      if (status.sheetValue.toLowerCase() == value.trim().toLowerCase()) {
        return status;
      }
    }
    return SaleStatus.pending;
  }
}
