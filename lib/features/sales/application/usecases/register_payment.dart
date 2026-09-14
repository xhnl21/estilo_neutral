import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/usecase/use_case.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/events/event_bus.dart';
import '../../domain/value_objects/sale_id.dart';
import '../../domain/value_objects/payment_method.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/customer_repository.dart';
import '../dtos/sale_dto.dart';

class RegisterPaymentParams {
  final String saleId;
  final double paymentAmount;
  final String paymentMethod;

  const RegisterPaymentParams({
    required this.saleId,
    required this.paymentAmount,
    required this.paymentMethod,
  });
}

class RegisterPaymentUseCase implements UseCase<SaleDto, RegisterPaymentParams> {
  final SaleRepository saleRepository;
  final CustomerRepository customerRepository;
  final EventBus eventBus;

  RegisterPaymentUseCase({
    required this.saleRepository,
    required this.customerRepository,
    required this.eventBus,
  });

  @override
  Future<Result<Failure, SaleDto>> call(RegisterPaymentParams params) async {
    try {
      final saleId = SaleId(params.saleId);
      final saleResult = await saleRepository.findById(saleId);
      if (saleResult.isFailure) {
        return Error(saleResult.failureOrNull!);
      }

      final sale = saleResult.getOrNull!;
      final payment = MoneyUsd(params.paymentAmount);
      final method = PaymentMethod.fromSheetValue(params.paymentMethod);

      sale.registerPayment(payment, method);

      final updateResult = await saleRepository.update(sale);
      if (updateResult.isFailure) {
        return Error(updateResult.failureOrNull!);
      }

      // Reducir deuda del cliente
      final customerResult = await customerRepository.findById(sale.customerId);
      if (customerResult.isSuccess) {
        final customer = customerResult.getOrNull!;
        customer.payDebt(payment);
        await customerRepository.update(customer);
      }

      // Publicar eventos post-persistencia
      for (final event in sale.domainEvents) {
        eventBus.publish(event);
      }

      return Success(SaleDto.fromDomain(sale));
    } on Failure catch (f) {
      return Error(f);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
