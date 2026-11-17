import 'package:equatable/equatable.dart';

enum PaymentWebviewStatus { initial, loading, ready, failure }

class PaymentWebviewState extends Equatable {
  const PaymentWebviewState({
    this.status = PaymentWebviewStatus.initial,
    this.message = '',
  });

  final PaymentWebviewStatus status;
  final String message;

  PaymentWebviewState copyWith({PaymentWebviewStatus? status, String? message}) {
    return PaymentWebviewState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}