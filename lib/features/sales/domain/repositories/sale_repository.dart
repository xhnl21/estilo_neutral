import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/value_objects/iso_date.dart';
import '../entities/sale.dart';
import '../value_objects/sale_id.dart';
import '../value_objects/customer_id.dart';

/// Contrato de repositorio para Sale (Domain Layer)
abstract class SaleRepository {
  Future<Result<Failure, Sale>> findById(SaleId id);
  Future<Result<Failure, List<Sale>>> findAll({bool forceRefresh = false});
  Future<Result<Failure, List<Sale>>> findByCustomer(CustomerId customerId);
  Future<Result<Failure, List<Sale>>> findByDate(IsoDate date);
  Future<Result<Failure, void>> save(Sale sale);
  Future<Result<Failure, void>> update(Sale sale);
}
