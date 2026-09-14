import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../entities/customer.dart';
import '../value_objects/customer_id.dart';

/// Contrato de repositorio para Customer (Domain Layer)
abstract class CustomerRepository {
  Future<Result<Failure, Customer>> findById(CustomerId id);
  Future<Result<Failure, List<Customer>>> findAll({bool forceRefresh = false});
  Future<Result<Failure, void>> save(Customer customer);
  Future<Result<Failure, void>> update(Customer customer);
}
