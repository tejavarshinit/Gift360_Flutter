import 'package:equatable/equatable.dart';

enum ResellerStatus { initial, loading, ready, failure }

class ResellerState extends Equatable {
  const ResellerState({
    this.status = ResellerStatus.initial,
    this.message = '',
  });

  final ResellerStatus status;
  final String message;

  ResellerState copyWith({ResellerStatus? status, String? message}) {
    return ResellerState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}