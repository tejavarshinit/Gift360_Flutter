import 'package:equatable/equatable.dart';

enum WelcomeStatus { initial, loading, ready, failure }

class WelcomeState extends Equatable {
  const WelcomeState({
    this.status = WelcomeStatus.initial,
    this.message = '',
  });

  final WelcomeStatus status;
  final String message;

  WelcomeState copyWith({WelcomeStatus? status, String? message}) {
    return WelcomeState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}