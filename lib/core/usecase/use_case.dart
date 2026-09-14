import '../error/failures.dart';
import '../types/either.dart';

/// Contrato base para Casos de Uso (Clean Architecture)
abstract class UseCase<Type, Params> {
  Future<Result<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
