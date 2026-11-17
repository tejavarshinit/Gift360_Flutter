import 'package:equatable/equatable.dart';

enum OrdersStatus { initial, loading, ready, failure }

class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.message = '',
  });

  final OrdersStatus status;
  final String message;

  OrdersState copyWith({OrdersStatus? status, String? message}) {
    return OrdersState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}