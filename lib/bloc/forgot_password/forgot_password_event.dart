import 'package:equatable/equatable.dart';

sealed class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object?> get props => const [];
}

class ForgotPasswordStarted extends ForgotPasswordEvent {
  const ForgotPasswordStarted();
}

class ForgotPasswordRefreshed extends ForgotPasswordEvent {
  const ForgotPasswordRefreshed();
}