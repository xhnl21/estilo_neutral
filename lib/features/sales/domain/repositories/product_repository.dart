import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../entities/product.dart';
import '../value_objects/product_id.dart';

/// Contrato de repositorio para Product (Domain Layer)
abstract class ProductRepository {
  Future<Result<Failure, Product>> findById(ProductId id);
  Future<Result<Failure, List<Product>>> findAll({bool forceRefresh = false});
  Future<Result<Failure, List<Product>>> findLowStock(int threshold);
  Future<Result<Failure, void>> save(Product product);
  Future<Result<Failure, void>> update(Product product);
}
