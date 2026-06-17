import 'package:firebase_core/firebase_core.dart';
import 'app_error.dart';

class ErrorMapper {
  static AppError map(dynamic exception, [StackTrace? stackTrace]) {
    if (exception is FirebaseException) {
      String message = exception.message ?? 'A Firebase error occurred.';
      
      // Map permission/authorization issues
      if (exception.code == 'unauthorized' || 
          exception.code == 'permission-denied' ||
          message.contains('not authorized') ||
          message.contains('permission-denied')) {
        message = 'You do not have permission to perform this action. Owner or Editor access is required.';
      } else if (exception.code == 'quota-exceeded') {
        message = 'Storage quota exceeded. Please contact your administrator.';
      } else if (exception.code == 'canceled') {
        message = 'The operation was canceled.';
      } else if (exception.code == 'object-not-found') {
        message = 'The requested file or folder could not be found.';
      } else if (exception.code == 'retry-limit-exceeded') {
        message = 'The operation timed out. Please check your internet connection.';
      }

      return AppError(
        code: exception.code,
        message: message,
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
