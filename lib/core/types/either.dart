/// Implementación funcional Either/Result<L, R>
abstract class Result<L, R> {
  const Result();

  bool get isSuccess => this is Success<L, R>;
  bool get isFailure => this is Error<L, R>;

  T fold<T>(T Function(L failure) ifFailure, T Function(R success) ifSuccess);

  R? get getOrNull => fold((_) => null, (r) => r);
  L? get failureOrNull => fold((l) => l, (_) => null);
}

class Success<L, R> extends Result<L, R> {
  final R data;
  const Success(this.data);

  @override
  T fold<T>(T Function(L failure) ifFailure, T Function(R success) ifSuccess) =>
      ifSuccess(data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<L, R> && other.data == data;

  @override
  int get hashCode => data.hashCode;
}

class Error<L, R> extends Result<L, R> {
  final L failure;
  const Error(this.failure);

  @override
  T fold<T>(T Function(L failure) ifFailure, T Function(R success) ifSuccess) =>
      ifFailure(failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Error<L, R> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
