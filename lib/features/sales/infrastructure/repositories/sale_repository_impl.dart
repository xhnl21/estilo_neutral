import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/value_objects/iso_date.dart';
import '../../domain/entities/sale.dart';
import '../../domain/value_objects/sale_id.dart';
import '../../domain/value_objects/customer_id.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/sales_sheets_datasource.dart';
import '../models/sale_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  final SalesSheetsDataSource dataSource;
  List<Sale>? _cache;

  SaleRepositoryImpl({required this.dataSource});

  @override
  Future<Result<Failure, Sale>> findById(SaleId id) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      for (final sale in allResult.getOrNull!) {
        if (sale.id.value == id.value) {
          return Success(sale);
        }
      }
      return Error(NotFoundFailure('Venta con ID "${id.value}" no encontrada.'));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<Sale>>> findAll({bool forceRefresh = false}) async {
    // No polling. Actualización bajo demanda del usuario.
    try {
      if (!forceRefresh && _cache != null) {
        return Success(_cache!);
      }
      final models = await dataSource.getSales();
      final entities = models.map((m) => m.toEntity()).toList();
      _cache = entities;
      return Success(entities);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<Sale>>> findByCustomer(CustomerId customerId) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      final filtered = allResult.getOrNull!
          .where((s) => s.customerId.value == customerId.value)
          .toList();
      return Success(filtered);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<Sale>>> findByDate(IsoDate date) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      final filtered = allResult.getOrNull!
          .where((s) => s.date.toIso8601String() == date.toIso8601String())
          .toList();
      return Success(filtered);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> save(Sale sale) async {
    try {
      _cache = null;
      final model = SaleModel.fromEntity(sale);
      await dataSource.saveSale(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> update(Sale sale) async {
    try {
      _cache = null;
      final model = SaleModel.fromEntity(sale);
      await dataSource.updateSale(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
