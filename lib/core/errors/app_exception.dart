class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  AppException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException({String message = 'No internet connection'})
      : super(message: message);
}

class TimeoutException extends AppException {
  TimeoutException({String message = 'Connection timeout'})
      : super(message: message);
}

class AuthException extends AppException {
  AuthException({String message = 'Authentication failed'})
      : super(message: message);
}

class ServerException extends AppException {
  ServerException({String message = 'Server error'})
      : super(message: message, statusCode: 500);
}

class CacheException extends AppException {
  CacheException({String message = 'Cache error'})
      : super(message: message);
}
