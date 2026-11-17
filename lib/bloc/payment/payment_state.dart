import 'package:equatable/equatable.dart';

enum PaymentStatus { initial, loading, ready, failure }

class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.initial,
    this.message = '',
  });

  final PaymentStatus status;
  final String message;

  PaymentState copyWith({PaymentStatus? status, String? message}) {
    return PaymentState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}