import 'package:equatable/equatable.dart';

enum OnboardingStatus { initial, loading, ready, failure }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.message = '',
  });

  final OnboardingStatus status;
  final String message;

  OnboardingState copyWith({OnboardingStatus? status, String? message}) {
    return OnboardingState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}