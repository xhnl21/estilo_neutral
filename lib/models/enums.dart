/// Enums de negocio para el sistema Estilo Neutral
/// Cumplimiento: ISO 8000 §4.2
library;

/// Tipos de pago permitidos en la hoja "ventas" (Columna H)
enum TipoPago {
  efectivo('Efectivo'),
  pagoMovil('Pago Movil'),
  transferencia('Transferencia'),
  zelle('Zelle'),
  binance('Binance'),
  otro('Otro');

  final String label;
  const TipoPago(this.label);

  static TipoPago fromString(String value) {
    for (final tipo in TipoPago.values) {
      if (tipo.label.toLowerCase() == value.trim().toLowerCase()) {
        return tipo;
      }
    }
    return TipoPago.otro;
  }
}

/// Estados de ciclo de vida de la transacción en la hoja "ventas" (Columna P)
enum EstadoVenta {
  pendiente('Pendiente'),
  pagada('Pagada'),
  anulada('Anulada'),
  cuarentena('Cuarentena');

  final String label;
  const EstadoVenta(this.label);

  static EstadoVenta fromString(String value) {
    for (final estado in EstadoVenta.values) {
      if (estado.label.toLowerCase() == value.trim().toLowerCase()) {
        return estado;
      }
    }
    return EstadoVenta.pendiente;
  }
}
