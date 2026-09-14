import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/usecase/use_case.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/product_repository.dart';

/// Caso de Uso: RefreshSalesDataUseCase
/// Equivalente al botón manual "Actualizar" en la UI (PULL MANUAL, CERO POLLING).
class RefreshSalesDataUseCase implements UseCase<void, NoParams> {
  final SaleRepository saleRepository;
  final CustomerRepository customerRepository;
  final ProductRepository productRepository;

  RefreshSalesDataUseCase({
    required this.saleRepository,
    required this.customerRepository,
    required this.productRepository,
  });

  @override
  Future<Result<Failure, void>> call(NoParams params) async {
    // No polling. Actualización bajo demanda del usuario.
    try {
      final resSales = await saleRepository.findAll(forceRefresh: true);
      if (resSales.isFailure) return Error(resSales.failureOrNull!);

      final resCust = await customerRepository.findAll(forceRefresh: true);
      if (resCust.isFailure) return Error(resCust.failureOrNull!);

      final resProd = await productRepository.findAll(forceRefresh: true);
      if (resProd.isFailure) return Error(resProd.failureOrNull!);

      return const Success(null);
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
