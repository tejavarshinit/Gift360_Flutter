import 'package:equatable/equatable.dart';

sealed class ResetPasswordEvent extends Equatable {
  const ResetPasswordEvent();

  @override
  List<Object?> get props => const [];
}

class ResetPasswordStarted extends ResetPasswordEvent {
  const ResetPasswordStarted();
}

class ResetPasswordRefreshed extends ResetPasswordEvent {
  const ResetPasswordRefreshed();
}