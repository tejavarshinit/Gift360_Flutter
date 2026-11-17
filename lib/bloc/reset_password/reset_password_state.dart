import 'package:equatable/equatable.dart';

enum ResetPasswordStatus { initial, loading, ready, failure }

class ResetPasswordState extends Equatable {
  const ResetPasswordState({
    this.status = ResetPasswordStatus.initial,
    this.message = '',
  });

  final ResetPasswordStatus status;
  final String message;

  ResetPasswordState copyWith({ResetPasswordStatus? status, String? message}) {
    return ResetPasswordState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}