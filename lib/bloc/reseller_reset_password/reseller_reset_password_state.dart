import 'package:equatable/equatable.dart';

enum ResellerResetPasswordStatus { initial, loading, ready, failure }

class ResellerResetPasswordState extends Equatable {
  const ResellerResetPasswordState({
    this.status = ResellerResetPasswordStatus.initial,
    this.message = '',
  });

  final ResellerResetPasswordStatus status;
  final String message;

  ResellerResetPasswordState copyWith({ResellerResetPasswordStatus? status, String? message}) {
    return ResellerResetPasswordState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}