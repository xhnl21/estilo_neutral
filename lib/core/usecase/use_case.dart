import '../error/failures.dart';
import '../types/either.dart';

/// Contrato base para Casos de Uso (Clean Architecture)
abstract class UseCase<T, Params> {
  Future<Result<Failure, T>> call(Params params);
}

class NoParams {
  const NoParams();
}
