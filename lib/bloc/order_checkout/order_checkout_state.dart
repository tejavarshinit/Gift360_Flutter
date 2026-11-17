import 'package:equatable/equatable.dart';

enum OrderCheckoutStatus { initial, loading, ready, failure }

class OrderCheckoutState extends Equatable {
  const OrderCheckoutState({
    this.status = OrderCheckoutStatus.initial,
    this.message = '',
  });

  final OrderCheckoutStatus status;
  final String message;

  OrderCheckoutState copyWith({OrderCheckoutStatus? status, String? message}) {
    return OrderCheckoutState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}