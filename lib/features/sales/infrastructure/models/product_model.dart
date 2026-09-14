import '../../domain/entities/product.dart';
import '../../domain/value_objects/product_id.dart';
import '../../domain/value_objects/stock_quantity.dart';
import '../../../../core/value_objects/money_usd.dart';

/// Modelo de Infraestructura: Mapeo 1:1 con la hoja "inventario"
class ProductModel {
  final String id;
  final int cantidad;
  final String nombre;
  final String marca;
  final String modelo;
  final String talla;
  final double precioUsd;
  final String? fotoUrl;
  final String? fotoFormula;

  const ProductModel({
    required this.id,
    required this.cantidad,
    required this.nombre,
    required this.marca,
    required this.modelo,
    required this.talla,
    required this.precioUsd,
    this.fotoUrl,
    this.fotoFormula,
  });

  factory ProductModel.fromRow(List<dynamic> row) {
    return ProductModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      cantidad: row.length > 1 ? int.tryParse(row[1].toString()) ?? 0 : 0,
      nombre: row.length > 2 ? row[2].toString() : '',
      marca: row.length > 3 ? row[3].toString() : '',
      modelo: row.length > 4 ? row[4].toString() : '',
      talla: row.length > 5 ? row[5].toString() : '',
      precioUsd: row.length > 6 ? double.tryParse(row[6].toString()) ?? 0.0 : 0.0,
      fotoUrl: row.length > 7 && row[7].toString().isNotEmpty ? row[7].toString() : null,
      fotoFormula: row.length > 8 ? row[8].toString() : null,
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
      fotoFormula ?? (fotoUrl != null && fotoUrl!.isNotEmpty ? '=IF(H2="","",IMAGE(H2))' : ''),
    ];
  }

  Product toEntity() {
    return Product(
      id: ProductId(id),
      stock: StockQuantity(cantidad),
      name: nombre,
      brand: marca,
      model: modelo,
      size: talla,
      priceUsd: MoneyUsd(precioUsd),
      photoUrl: fotoUrl,
    );
  }

  factory ProductModel.fromEntity(Product entity) {
    return ProductModel(
      id: entity.id.value,
      cantidad: entity.stock.value,
      nombre: entity.name,
      marca: entity.brand,
      modelo: entity.model,
      talla: entity.size,
      precioUsd: entity.priceUsd.value,
      fotoUrl: entity.photoUrl,
    );
  }
}
