import 'package:equatable/equatable.dart';

sealed class ResellerResetPasswordEvent extends Equatable {
  const ResellerResetPasswordEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerResetPasswordStarted extends ResellerResetPasswordEvent {
  const ResellerResetPasswordStarted();
}

class ResellerResetPasswordRefreshed extends ResellerResetPasswordEvent {
  const ResellerResetPasswordRefreshed();
}