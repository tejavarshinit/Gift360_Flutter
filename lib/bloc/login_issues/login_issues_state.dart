import 'package:equatable/equatable.dart';

enum LoginIssuesStatus { initial, loading, ready, failure }

class LoginIssuesState extends Equatable {
  const LoginIssuesState({
    this.status = LoginIssuesStatus.initial,
    this.message = '',
  });

  final LoginIssuesStatus status;
  final String message;

  LoginIssuesState copyWith({LoginIssuesStatus? status, String? message}) {
    return LoginIssuesState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}