import '../../../../models/producto.dart';
import 'search_match.dart';
import 'searchable_item.dart';

/// Entidad de dominio que representa un producto del inventario sincronizado
/// desde la nube (Google Sheets) para búsqueda reactiva y tolerante a fallos.
class InventarioItem extends SearchableItem {
  /// Marca comercial de la prenda o producto (ej. 'Nike', 'Zara', 'Levi\'s').
  final String marca;

  /// Modelo específico del producto (ej. 'Sport Classic', 'Slim Fit 511').
  final String modelo;

  /// Talla comercial (ej. 'S', 'M', 'L', 'XL', '32', '40').
  final String talla;

  /// Cantidad en stock disponible en inventario (>= 0).
  final int cantidad;

  /// Precio unitario de venta en USD.
  final double precioUsd;

  /// Enlace directo a la fotografía en Google Drive (opcional).
  final String? fotoUrl;

  /// Crea una entidad de inventario indexable y evaluable por el buscador.
  const InventarioItem({
    required super.id,
    required super.name,
    required this.marca,
    required this.modelo,
    required this.talla,
    required this.cantidad,
    required this.precioUsd,
    this.fotoUrl,
    super.searchResult,
  });

  /// Construye un [InventarioItem] a partir del modelo [Producto] proveniente
  /// de la hoja de cálculo de Google Sheets en la nube.
  factory InventarioItem.fromProducto(Producto producto, [SearchResult? searchResult]) {
    return InventarioItem(
      id: producto.id,
      name: producto.nombre,
      marca: producto.marca,
      modelo: producto.modelo,
      talla: producto.talla,
      cantidad: producto.cantidad,
      precioUsd: producto.precioUsd,
      fotoUrl: producto.fotoUrl,
      searchResult: searchResult,
    );
  }

  @override
  InventarioItem copyWithSearchResult(SearchResult? result) {
    return InventarioItem(
      id: id,
      name: name,
      marca: marca,
      modelo: modelo,
      talla: talla,
      cantidad: cantidad,
      precioUsd: precioUsd,
      fotoUrl: fotoUrl,
      searchResult: result,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        marca,
        modelo,
        talla,
        cantidad,
        precioUsd,
        fotoUrl,
        searchResult,
      ];
}
