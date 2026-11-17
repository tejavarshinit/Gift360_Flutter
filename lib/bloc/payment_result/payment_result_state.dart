import 'package:equatable/equatable.dart';

enum PaymentResultStatus { initial, loading, ready, failure }

class PaymentResultState extends Equatable {
  const PaymentResultState({
    this.status = PaymentResultStatus.initial,
    this.message = '',
  });

  final PaymentResultStatus status;
  final String message;

  PaymentResultState copyWith({PaymentResultStatus? status, String? message}) {
    return PaymentResultState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}