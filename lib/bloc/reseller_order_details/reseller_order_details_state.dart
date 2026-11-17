import 'package:equatable/equatable.dart';

enum ResellerOrderDetailsStatus { initial, loading, ready, failure }

class ResellerOrderDetailsState extends Equatable {
  const ResellerOrderDetailsState({
    this.status = ResellerOrderDetailsStatus.initial,
    this.message = '',
  });

  final ResellerOrderDetailsStatus status;
  final String message;

  ResellerOrderDetailsState copyWith({ResellerOrderDetailsStatus? status, String? message}) {
    return ResellerOrderDetailsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}