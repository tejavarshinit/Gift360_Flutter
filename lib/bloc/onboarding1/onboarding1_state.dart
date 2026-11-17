import 'package:equatable/equatable.dart';

enum Onboarding1Status { initial, loading, ready, failure }

class Onboarding1State extends Equatable {
  const Onboarding1State({
    this.status = Onboarding1Status.initial,
    this.message = '',
  });

  final Onboarding1Status status;
  final String message;

  Onboarding1State copyWith({Onboarding1Status? status, String? message}) {
    return Onboarding1State(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}