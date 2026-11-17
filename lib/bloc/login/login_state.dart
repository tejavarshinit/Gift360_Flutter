import 'package:equatable/equatable.dart';

enum LoginStatus { initial, loading, ready, failure }

class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.message = '',
  });

  final LoginStatus status;
  final String message;

  LoginState copyWith({LoginStatus? status, String? message}) {
    return LoginState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}