/// Modelo de entidad Método de Pago mapeado desde la hoja "metodo pago".
/// Permite gestionar dinámicamente los métodos de pago disponibles en el sistema.
class MetodoPago {
  /// Identificador único (ej: mp00000001)
  final String id;

  /// Nombre legible del método de pago (ej: Efectivo, Pago Movil, Zelle, etc.)
  final String nombre;

  /// Estado de activación: si es true, está activo y visible en los selectores;
  /// si es false, está inactivo/deshabilitado.
  final bool status;

  const MetodoPago({
    required this.id,
    required this.nombre,
    this.status = true,
  });

  factory MetodoPago.fromRow(List<dynamic> row) {
    final rawStatus = row.length > 2 ? row[2] : true;
    final parsedStatus = _parseStatus(rawStatus);

    return MetodoPago(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      nombre: row.length > 1 ? row[1].toString().trim() : '',
      status: parsedStatus,
    );
  }

  static bool _parseStatus(dynamic value) {
    if (value is bool) return value;
    final s = value.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'activo' || s == 'si' || s == 'sí';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'status': status,
    };
  }

  MetodoPago copyWith({
    String? id,
    String? nombre,
    bool? status,
  }) {
    return MetodoPago(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetodoPago &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MetodoPago(id: $id, nombre: $nombre, status: $status)';
}
