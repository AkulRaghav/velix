/// `Result<S, E>` — values across layer boundaries instead of exceptions.
///
/// Layers must not throw exceptions across their public API. They return
/// `Result.ok(...)` or `Result.err(...)`. Internal exceptions inside a
/// layer are caught and converted at the boundary by [Result.guard].
sealed class Result<S, E> {
  const Result();

  T when<T>({
    required T Function(S value) ok,
    required T Function(E error) err,
  }) =>
      switch (this) {
        Ok<S, E>(:final value) => ok(value),
        Err<S, E>(:final error) => err(error),
      };

  bool get isOk => this is Ok<S, E>;
  bool get isErr => this is Err<S, E>;

  S? get valueOrNull => switch (this) {
        Ok<S, E>(:final value) => value,
        Err<S, E>() => null,
      };

  E? get errorOrNull => switch (this) {
        Ok<S, E>() => null,
        Err<S, E>(:final error) => error,
      };

  Result<S2, E> map<S2>(S2 Function(S value) f) => switch (this) {
        Ok<S, E>(:final value) => Ok(f(value)),
        Err<S, E>(:final error) => Err(error),
      };

  Result<S, E2> mapError<E2>(E2 Function(E error) f) => switch (this) {
        Ok<S, E>(:final value) => Ok(value),
        Err<S, E>(:final error) => Err(f(error)),
      };
}

final class Ok<S, E> extends Result<S, E> {
  const Ok(this.value);
  final S value;
}

final class Err<S, E> extends Result<S, E> {
  const Err(this.error);
  final E error;
}
