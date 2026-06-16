import 'package:firebase_core/firebase_core.dart';
import 'app_error.dart';

class ErrorMapper {
  static AppError map(dynamic exception, [StackTrace? stackTrace]) {
    if (exception is FirebaseException) {
      return AppError(
        code: exception.code,
        message: exception.message ?? 'A Firebase error occurred.',
        details: exception,
        stackTrace: stackTrace,
      );
    }

    return AppError(
      code: 'unknown',
      message: exception.toString(),
      details: exception,
      stackTrace: stackTrace,
    );
  }
}
