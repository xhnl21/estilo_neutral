import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../domain/entities/currency_purchase.dart';
import '../../domain/value_objects/purchase_id.dart';
import '../../domain/repositories/currency_purchase_repository.dart';
import '../datasources/treasury_sheets_datasource.dart';
import '../models/currency_purchase_model.dart';

class CurrencyPurchaseRepositoryImpl implements CurrencyPurchaseRepository {
  final TreasurySheetsDataSource dataSource;
  List<CurrencyPurchase>? _cache;

  CurrencyPurchaseRepositoryImpl({required this.dataSource});

  @override
  Future<Result<Failure, CurrencyPurchase>> findById(PurchaseId id) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      for (final p in allResult.getOrNull!) {
        if (p.id.value == id.value) {
          return Success(p);
        }
      }
      return Error(NotFoundFailure('Compra con ID "${id.value}" no encontrada.'));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<CurrencyPurchase>>> findAll({bool forceRefresh = false}) async {
    // No polling. Actualización bajo demanda del usuario.
    try {
      if (!forceRefresh && _cache != null) {
        return Success(_cache!);
      }
      final models = await dataSource.getPurchases();
      final entities = models.map((m) => m.toEntity()).toList();
      _cache = entities;
      return Success(entities);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> save(CurrencyPurchase purchase) async {
    try {
      _cache = null;
      final model = CurrencyPurchaseModel.fromEntity(purchase);
      await dataSource.savePurchase(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
