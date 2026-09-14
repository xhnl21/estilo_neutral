import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../entities/currency_purchase.dart';
import '../value_objects/purchase_id.dart';

abstract class CurrencyPurchaseRepository {
  Future<Result<Failure, CurrencyPurchase>> findById(PurchaseId id);
  Future<Result<Failure, List<CurrencyPurchase>>> findAll({bool forceRefresh = false});
  Future<Result<Failure, void>> save(CurrencyPurchase purchase);
}
