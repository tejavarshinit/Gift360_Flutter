import 'package:equatable/equatable.dart';

enum CartStatus { initial, loading, ready, failure }

class CartState extends Equatable {
  const CartState({
    this.status = CartStatus.initial,
    this.message = '',
  });

  final CartStatus status;
  final String message;

  CartState copyWith({CartStatus? status, String? message}) {
    return CartState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}