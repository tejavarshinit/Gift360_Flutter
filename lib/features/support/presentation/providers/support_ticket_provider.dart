import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/support/data/repositories/support_ticket_api.dart';

/// Thrown when posting to a ticket the backend has already closed.
/// Matches React's TicketClosedError class.
class TicketClosedError implements Exception {
  final String message;
  TicketClosedError(this.message);
  @override
  String toString() => message;
}

final supportTicketApiProvider = Provider<SupportTicketApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return SupportTicketApi(dio);
});

class TicketMessage {
  final String senderType;
  final String message;
  final String createdAt;

  TicketMessage({
    required this.senderType,
    required this.message,
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      senderType: json['senderType'] ?? 'USER',
      message: json['message'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class SupportTicketState {
  final bool isCreating;
  final bool isSending;
  final bool isLoadingThread;
  final String? publicId;
  final String? error;
  final bool isSuccess;
  final List<TicketMessage> messages;
  final String? ticketStatus;

  const SupportTicketState({
    this.isCreating = false,
    this.isSending = false,
    this.isLoadingThread = false,
    this.publicId,
    this.error,
    this.isSuccess = false,
    this.messages = const [],
    this.ticketStatus,
  });

  SupportTicketState copyWith({
    bool? isCreating,
    bool? isSending,
    bool? isLoadingThread,
    String? publicId,
    String? error,
    bool? isSuccess,
    List<TicketMessage>? messages,
    String? ticketStatus,
    bool clearError = false,
  }) {
    return SupportTicketState(
      isCreating: isCreating ?? this.isCreating,
      isSending: isSending ?? this.isSending,
      isLoadingThread: isLoadingThread ?? this.isLoadingThread,
      publicId: publicId ?? this.publicId,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      messages: messages ?? this.messages,
      ticketStatus: ticketStatus ?? this.ticketStatus,
    );
  }
}

class SupportTicketNotifier extends StateNotifier<SupportTicketState> {
  final SupportTicketApi _api;

  SupportTicketNotifier(this._api) : super(const SupportTicketState());

  Future<bool> createTicket({
    required String name,
    String? email,
    String? mobile,
    String? subject,
    required String message,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final result = await _api.createTicket(
        name: name,
        email: email,
        mobile: mobile,
        subject: subject,
        message: message,
      );
      state = state.copyWith(
        isCreating: false,
        isSuccess: true,
        publicId: result['publicId'] as String?,
        ticketStatus: result['status'] as String?,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadThread(String publicId) async {
    state = state.copyWith(isLoadingThread: true, clearError: true);
    try {
      final result = await _api.getThread(publicId);
      final messages = (result['data'] as List?)
              ?.map((m) => TicketMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];
      state = state.copyWith(
        isLoadingThread: false,
        messages: messages,
        publicId: publicId,
        ticketStatus: result['status'] as String?,
      );
    } catch (e) {
      state = state.copyWith(isLoadingThread: false, error: e.toString());
    }
  }

  Future<bool> sendMessage(String publicId, String message) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result = await _api.sendMessage(publicId, message);
      final newMessage = TicketMessage.fromJson(result['data'] as Map<String, dynamic>? ?? result);
      state = state.copyWith(
        isSending: false,
        messages: [...state.messages, newMessage],
      );
      return true;
    } on DioException catch (e) {
      // Check for TICKET_CLOSED error code (matches React's TicketClosedError)
      final data = e.response?.data;
      if (data is Map && data['errorCode'] == 'TICKET_CLOSED') {
        final msg = data['message'] as String? ?? 'This conversation is closed.';
        state = state.copyWith(isSending: false, error: msg, ticketStatus: 'CLOSED');
      } else {
        state = state.copyWith(isSending: false, error: e.toString());
      }
      return false;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const SupportTicketState();
  }
}

final supportTicketProvider =
    StateNotifierProvider<SupportTicketNotifier, SupportTicketState>((ref) {
  return SupportTicketNotifier(ref.watch(supportTicketApiProvider));
});
