import 'package:equatable/equatable.dart';

enum Onboarding3Status { initial, loading, ready, failure }

class Onboarding3State extends Equatable {
  const Onboarding3State({
    this.status = Onboarding3Status.initial,
    this.message = '',
  });

  final Onboarding3Status status;
  final String message;

  Onboarding3State copyWith({Onboarding3Status? status, String? message}) {
    return Onboarding3State(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}