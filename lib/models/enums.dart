/// Enums de negocio para el sistema Estilo Neutral
/// Cumplimiento: ISO 8000 §4.2
library;

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
