import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../domain/entities/product.dart';
import '../../domain/value_objects/product_id.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/sales_sheets_datasource.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final SalesSheetsDataSource dataSource;
  List<Product>? _cache;

  ProductRepositoryImpl({required this.dataSource});

  @override
  Future<Result<Failure, Product>> findById(ProductId id) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      for (final prod in allResult.getOrNull!) {
        if (prod.id.value == id.value) {
          return Success(prod);
        }
      }
      return Error(NotFoundFailure('Producto con ID "${id.value}" no encontrado.'));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<Product>>> findAll({bool forceRefresh = false}) async {
    // No polling. Actualización bajo demanda del usuario.
    try {
      if (!forceRefresh && _cache != null) {
        return Success(_cache!);
      }
      final models = await dataSource.getProducts();
      final entities = models.map((m) => m.toEntity()).toList();
      _cache = entities;
      return Success(entities);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<Product>>> findLowStock(int threshold) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      final filtered = allResult.getOrNull!
          .where((p) => p.stock.value <= threshold)
          .toList();
      return Success(filtered);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> save(Product product) async {
    try {
      _cache = null;
      final model = ProductModel.fromEntity(product);
      await dataSource.saveProduct(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> update(Product product) async {
    try {
      _cache = null;
      final model = ProductModel.fromEntity(product);
      await dataSource.updateProduct(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
