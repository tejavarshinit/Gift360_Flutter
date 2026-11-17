import 'package:equatable/equatable.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => const [];
}

class LoginStarted extends LoginEvent {
  const LoginStarted();
}

class LoginRefreshed extends LoginEvent {
  const LoginRefreshed();
}