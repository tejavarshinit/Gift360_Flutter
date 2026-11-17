import 'package:equatable/equatable.dart';

enum ForgotPasswordStatus { initial, loading, ready, failure }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.status = ForgotPasswordStatus.initial,
    this.message = '',
  });

  final ForgotPasswordStatus status;
  final String message;

  ForgotPasswordState copyWith({ForgotPasswordStatus? status, String? message}) {
    return ForgotPasswordState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}