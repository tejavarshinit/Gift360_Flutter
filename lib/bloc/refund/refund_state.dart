import 'package:equatable/equatable.dart';

enum RefundStatus { initial, loading, ready, failure }

class RefundState extends Equatable {
  const RefundState({
    this.status = RefundStatus.initial,
    this.message = '',
  });

  final RefundStatus status;
  final String message;

  RefundState copyWith({RefundStatus? status, String? message}) {
    return RefundState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}