import 'package:equatable/equatable.dart';

enum MyOrdersStatus { initial, loading, ready, failure }

class MyOrdersState extends Equatable {
  const MyOrdersState({
    this.status = MyOrdersStatus.initial,
    this.message = '',
  });

  final MyOrdersStatus status;
  final String message;

  MyOrdersState copyWith({MyOrdersStatus? status, String? message}) {
    return MyOrdersState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}