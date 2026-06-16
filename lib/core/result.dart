import 'app_error.dart';

sealed class Result<T> {
  const Result();

  R fold<R>(
    R Function(T data) onSuccess,
    R Function(AppError error) onFailure,
  ) {
    if (this is Success<T>) {
      return onSuccess((this as Success<T>).data);
    } else if (this is Failure<T>) {
      return onFailure((this as Failure<T>).error);
    }
    throw StateError('Unknown subclass of Result');
  }

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  AppError? get errorOrNull => this is Failure<T> ? (this as Failure<T>).error : null;
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}
