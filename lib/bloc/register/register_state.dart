import 'package:equatable/equatable.dart';

enum RegisterStatus { initial, loading, ready, failure }

class RegisterState extends Equatable {
  const RegisterState({
    this.status = RegisterStatus.initial,
    this.message = '',
  });

  final RegisterStatus status;
  final String message;

  RegisterState copyWith({RegisterStatus? status, String? message}) {
    return RegisterState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}