import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../domain/entities/customer.dart';
import '../../domain/value_objects/customer_id.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/sales_sheets_datasource.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final SalesSheetsDataSource dataSource;
  List<Customer>? _cache;

  CustomerRepositoryImpl({required this.dataSource});

  @override
  Future<Result<Failure, Customer>> findById(CustomerId id) async {
    try {
      final allResult = await findAll();
      if (allResult.isFailure) return Error(allResult.failureOrNull!);
      final list = allResult.getOrNull!;
      for (final cust in list) {
        if (cust.id.value == id.value) {
          return Success(cust);
        }
      }
      return Error(NotFoundFailure('Cliente con ID "${id.value}" no encontrado.'));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, List<Customer>>> findAll({bool forceRefresh = false}) async {
    // No polling. Actualización bajo demanda del usuario.
    try {
      if (!forceRefresh && _cache != null) {
        return Success(_cache!);
      }
      final models = await dataSource.getCustomers();
      final entities = models.map((m) => m.toEntity()).toList();
      _cache = entities;
      return Success(entities);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> save(Customer customer) async {
    try {
      _cache = null; // invalidar caché
      final model = CustomerModel.fromEntity(customer);
      await dataSource.saveCustomer(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Failure, void>> update(Customer customer) async {
    try {
      _cache = null;
      final model = CustomerModel.fromEntity(customer);
      await dataSource.updateCustomer(model);
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
