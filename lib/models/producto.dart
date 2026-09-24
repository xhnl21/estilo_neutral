import 'number_parser.dart';

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

  /// Columna H: Clave foránea a la hoja "galeria" (id de la foto subida) —
  /// nunca la URL directa, para no duplicar esa fuente de verdad (ver
  /// SheetsDataService.fotoUrlPorId). Null si el producto no tiene foto.
  final String? fotoId;

  /// Nota: La Columna I ("foto") no se mapea en el cliente,
  /// ya que es una fórmula calculada en la hoja que resuelve fotoId contra
  /// "galeria" (=IMAGE(VLOOKUP(H, galeria!A:B, 2, FALSE))).

  /// Columna J: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const Producto({
    required this.id,
    required this.cantidad,
    required this.nombre,
    required this.marca,
    required this.modelo,
    required this.talla,
    required this.precioUsd,
    this.fotoId,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  factory Producto.fromRow(List<dynamic> row) {
    return Producto(
      id: row.isNotEmpty ? row[0].toString() : '',
      cantidad: row.length > 1 ? parseSheetInt(row[1]) : 0,
      nombre: row.length > 2 ? row[2].toString() : '',
      marca: row.length > 3 ? row[3].toString() : '',
      modelo: row.length > 4 ? row[4].toString() : '',
      talla: row.length > 5 ? row[5].toString() : '',
      precioUsd: row.length > 6 ? parseSheetDouble(row[6]) : 0.0,
      fotoId: row.length > 7 && row[7].toString().isNotEmpty ? row[7].toString() : null,
      organizacionId: row.length > 9 && row[9].toString().trim().isNotEmpty
          ? row[9].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
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
      'foto_id': fotoId ?? '',
      'organizacion_id': organizacionId,
    };
  }
}
