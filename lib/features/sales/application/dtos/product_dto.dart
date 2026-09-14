import '../../domain/entities/product.dart';

class ProductDto {
  final String id;
  final int stock;
  final String name;
  final String brand;
  final String model;
  final String size;
  final double priceUsd;
  final String? photoUrl;

  const ProductDto({
    required this.id,
    required this.stock,
    required this.name,
    required this.brand,
    required this.model,
    required this.size,
    required this.priceUsd,
    this.photoUrl,
  });

  factory ProductDto.fromDomain(Product product) {
    return ProductDto(
      id: product.id.value,
      stock: product.stock.value,
      name: product.name,
      brand: product.brand,
      model: product.model,
      size: product.size,
      priceUsd: product.priceUsd.value,
      photoUrl: product.photoUrl,
    );
  }
}
