import 'package:equatable/equatable.dart';

enum ResellerCartStatus { initial, loading, ready, failure }

class ResellerCartState extends Equatable {
  const ResellerCartState({
    this.status = ResellerCartStatus.initial,
    this.message = '',
  });

  final ResellerCartStatus status;
  final String message;

  ResellerCartState copyWith({ResellerCartStatus? status, String? message}) {
    return ResellerCartState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}