/// Modelo de entidad Producto mapeado desde la hoja "inventario"
/// Norma: ISO 8000 §4.2 / RFC 3986
class Producto {
  /// Columna A: ID de producto (formato p00000001)
  final String id;

  /// Columna B: Cantidad entera en stock (>= 0)
  final int cantidad;

  /// Columna C: Nombre de la prenda
  final String nombre;

  /// Columna D: Marca
  final String marca;

  /// Columna E: Modelo
  final String modelo;

  /// Columna F: Talla (ej: M, L, 32)
  final String talla;

  /// Columna G: Precio de venta unitario en USD
  final double precioUsd;

  /// Columna H: Enlace directo a la imagen en Google Drive (opcional)
  final String? fotoUrl;

  /// Nota: La Columna I ("foto") no se mapea en el cliente,
  /// ya que es una fórmula calculada =IMAGE(foto_url) en la hoja.

  const Producto({
    required this.id,
    required this.cantidad,
    required this.nombre,
    required this.marca,
    required this.modelo,
    required this.talla,
    required this.precioUsd,
    this.fotoUrl,
  });

  factory Producto.fromRow(List<dynamic> row) {
    return Producto(
      id: row.isNotEmpty ? row[0].toString() : '',
      cantidad: row.length > 1 ? int.tryParse(row[1].toString()) ?? 0 : 0,
      nombre: row.length > 2 ? row[2].toString() : '',
      marca: row.length > 3 ? row[3].toString() : '',
      modelo: row.length > 4 ? row[4].toString() : '',
      talla: row.length > 5 ? row[5].toString() : '',
      precioUsd: row.length > 6 ? double.tryParse(row[6].toString()) ?? 0.0 : 0.0,
      fotoUrl: row.length > 7 && row[7].toString().isNotEmpty ? row[7].toString() : null,
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      cantidad,
      nombre,
      marca,
      modelo,
      talla,
      precioUsd.toStringAsFixed(2),
      fotoUrl ?? '',
      fotoUrl != null && fotoUrl!.isNotEmpty ? '=IF(H2="","",IMAGE(H2))' : '',
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cantidad': cantidad,
      'nombre': nombre,
      'marca': marca,
      'modelo': modelo,
      'talla': talla,
      'precio_usd': precioUsd,
      'foto_url': fotoUrl,
    };
  }
}
