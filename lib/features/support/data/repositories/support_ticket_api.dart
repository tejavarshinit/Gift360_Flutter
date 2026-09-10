import 'package:dio/dio.dart';

class SupportTicketApi {
  final Dio _dio;

  SupportTicketApi(this._dio);

  Future<Map<String, dynamic>> createTicket({
    required String name,
    String? email,
    String? mobile,
    String? subject,
    required String message,
  }) async {
    final response = await _dio.post('/v1/support/tickets', data: {
      'name': name,
      if (email != null) 'email': email,
      if (mobile != null) 'mobile': mobile,
      if (subject != null) 'subject': subject,
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(String publicId, String message) async {
    final response = await _dio.post('/v1/support/tickets/$publicId/messages', data: {
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getThread(String publicId) async {
    final response = await _dio.get('/v1/support/tickets/$publicId/messages');
    return response.data as Map<String, dynamic>;
  }
}
