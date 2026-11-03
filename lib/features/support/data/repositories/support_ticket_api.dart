import 'package:dio/dio.dart';

/// Thrown when posting to a ticket the backend has already closed.
class TicketClosedException implements Exception {
  final String message;
  TicketClosedException(this.message);
  @override
  String toString() => message;
}

class SupportTicketApiException implements Exception {
  final String message;
  SupportTicketApiException(this.message);

  @override
  String toString() => message;
}

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
    // Match React's brandApi client: it adds the bearer token for logged-in
    // users and omits it for guests. Sending this through a separate public
    // client caused authenticated ticket creation to fail on the backend.
    final response = await _dio.post(
      '/v1/support/tickets',
      data: {
        'name': name,
        if (email?.isNotEmpty ?? false) 'email': email,
        if (mobile?.isNotEmpty ?? false) 'mobile': mobile,
        if (subject != null) 'subject': subject,
        'message': message,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw SupportTicketApiException(
        'Unexpected response from support. Please try again.',
      );
    }
    final result = Map<String, dynamic>.from(data);
    if (result['success'] == false) {
      final message = result['message']?.toString().trim();
      throw SupportTicketApiException(
        message == null || message.isEmpty
            ? 'Failed to start the conversation. Please try again.'
            : message,
      );
    }
    if ((result['publicId'] ?? '').toString().isEmpty) {
      throw SupportTicketApiException(
        'Support did not return a conversation ID. Please try again.',
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> sendMessage(
    String publicId,
    String message,
  ) async {
    try {
      final response = await _dio.post(
        '/v1/support/tickets/$publicId/messages',
        data: {'message': message},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['errorCode'] == 'TICKET_CLOSED') {
        throw TicketClosedException(
          (data['message'] as String?) ?? 'This conversation is closed.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getThread(String publicId) async {
    final response = await _dio.get('/v1/support/tickets/$publicId/messages');
    return response.data as Map<String, dynamic>;
  }

  Future<void> sendFeedback(String publicId, int messageId, String vote) async {
    await _dio.post(
      '/v1/support/tickets/$publicId/messages/$messageId/feedback',
      data: {'vote': vote},
    );
  }
}
