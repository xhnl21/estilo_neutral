import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/usecase/use_case.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../domain/value_objects/customer_id.dart';
import '../../domain/repositories/customer_repository.dart';

class GetCustomerDebtUseCase implements UseCase<MoneyUsd, String> {
  final CustomerRepository customerRepository;

  GetCustomerDebtUseCase({required this.customerRepository});

  @override
  Future<Result<Failure, MoneyUsd>> call(String customerIdStr) async {
    try {
      final customerId = CustomerId(customerIdStr);
      final result = await customerRepository.findById(customerId);
      if (result.isFailure) {
        return Error(result.failureOrNull!);
      }
      return Success(result.getOrNull!.debtBalance);
    } on Failure catch (f) {
      return Error(f);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
