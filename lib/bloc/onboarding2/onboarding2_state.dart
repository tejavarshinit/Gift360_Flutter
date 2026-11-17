import 'package:equatable/equatable.dart';

enum Onboarding2Status { initial, loading, ready, failure }

class Onboarding2State extends Equatable {
  const Onboarding2State({
    this.status = Onboarding2Status.initial,
    this.message = '',
  });

  final Onboarding2Status status;
  final String message;

  Onboarding2State copyWith({Onboarding2Status? status, String? message}) {
    return Onboarding2State(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}