import '../../../../core/error/failures.dart';
import '../../../../core/types/either.dart';
import '../../../../core/usecase/use_case.dart';
import '../../domain/repositories/product_repository.dart';
import '../dtos/product_dto.dart';

class ListProductsUseCase implements UseCase<List<ProductDto>, bool> {
  final ProductRepository productRepository;

  ListProductsUseCase({required this.productRepository});

  @override
  Future<Result<Failure, List<ProductDto>>> call(bool forceRefresh) async {
    // No polling. Actualización bajo demanda del usuario.
    final result = await productRepository.findAll(forceRefresh: forceRefresh);
    return result.fold(
      (failure) => Error(failure),
      (products) => Success(products.map((p) => ProductDto.fromDomain(p)).toList()),
    );
  }
}
