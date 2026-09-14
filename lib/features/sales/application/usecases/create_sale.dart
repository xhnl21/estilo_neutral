import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/usecase/use_case.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/money_bs.dart';
import '../../../../core/value_objects/exchange_rate.dart';
import '../../../../core/value_objects/iso_date.dart';
import '../../../../core/events/event_bus.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/value_objects/sale_id.dart';
import '../../domain/value_objects/customer_id.dart';
import '../../domain/value_objects/product_id.dart';
import '../../domain/value_objects/payment_method.dart';
import '../../domain/value_objects/sale_status.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/customer_repository.dart';
import '../dtos/sale_dto.dart';

class CreateSaleParams {
  final String saleId;
  final String customerId;
  final String productId;
  final int quantity;
  final double bcvRate;
  final double usdRate;
  final String paymentMethod;
  final double mobilePaymentFeeBs;
  final double paidAmount;

  const CreateSaleParams({
    required this.saleId,
    required this.customerId,
    required this.productId,
    required this.quantity,
    required this.bcvRate,
    required this.usdRate,
    required this.paymentMethod,
    required this.mobilePaymentFeeBs,
    required this.paidAmount,
  });
}

class CreateSaleUseCase implements UseCase<SaleDto, CreateSaleParams> {
  final SaleRepository saleRepository;
  final ProductRepository productRepository;
  final CustomerRepository customerRepository;
  final EventBus eventBus;

  CreateSaleUseCase({
    required this.saleRepository,
    required this.productRepository,
    required this.customerRepository,
    required this.eventBus,
  });

  @override
  Future<Result<Failure, SaleDto>> call(CreateSaleParams params) async {
    try {
      final customerId = CustomerId(params.customerId);
      final productId = ProductId(params.productId);
      final saleId = SaleId(params.saleId);

      // 1. Validar existencia de cliente (FK check)
      final customerResult = await customerRepository.findById(customerId);
      if (customerResult.isFailure) {
        return Error(customerResult.failureOrNull!);
      }

      // 2. Validar existencia y stock de producto
      final productResult = await productRepository.findById(productId);
      if (productResult.isFailure) {
        return Error(productResult.failureOrNull!);
      }
      final product = productResult.getOrNull!;
      if (product.stock.value < params.quantity) {
        return const Error(ValidationFailure('Stock insuficiente para la venta.'));
      }

      // 3. Construir agregado Sale
      final item = SaleItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        productId: productId,
        quantity: params.quantity,
        unitPriceUsd: product.priceUsd,
      );

      final sale = Sale(
        id: saleId,
        date: IsoDate.now(),
        customerId: customerId,
        items: [item],
        bcvRate: ExchangeRate(params.bcvRate),
        usdRate: ExchangeRate(params.usdRate),
        paymentMethod: PaymentMethod.fromSheetValue(params.paymentMethod),
        mobilePaymentFeeBs: MoneyBs(params.mobilePaymentFeeBs),
        paidAmount: MoneyUsd(params.paidAmount),
        status: SaleStatus.pending,
      );

      // 4. Persistir en repositorio
      final saveResult = await saleRepository.save(sale);
      if (saveResult.isFailure) {
        return Error(saveResult.failureOrNull!);
      }

      // 5. Decrementar stock y actualizar producto
      product.decrementStock(params.quantity);
      await productRepository.update(product);

      // 6. Actualizar deuda del cliente si aplica
      if (sale.deudaUsd.value > 0) {
        final customer = customerResult.getOrNull!;
        customer.increaseDebt(sale.deudaUsd);
        await customerRepository.update(customer);
      }

      // 7. Publicar eventos post-persistencia
      for (final event in sale.domainEvents) {
        eventBus.publish(event);
      }
      for (final event in product.domainEvents) {
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
