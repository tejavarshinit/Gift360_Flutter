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
  NetworkException({super.message = 'No internet connection'});
}

class TimeoutException extends AppException {
  TimeoutException({super.message = 'Connection timeout'});
}

class AuthException extends AppException {
  AuthException({super.message = 'Authentication failed'});
}

class ServerException extends AppException {
  ServerException({super.message = 'Server error'})
      : super(statusCode: 500);
}

class CacheException extends AppException {
  CacheException({super.message = 'Cache error'});
}
