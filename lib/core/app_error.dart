class AppError {
  final String code;
  final String message;
  final dynamic details;
  final StackTrace? stackTrace;

  const AppError({
    required this.code,
    required this.message,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() => 'AppError[$code]: $message';
}
