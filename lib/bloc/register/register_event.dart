import 'package:equatable/equatable.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => const [];
}

class RegisterStarted extends RegisterEvent {
  const RegisterStarted();
}

class RegisterRefreshed extends RegisterEvent {
  const RegisterRefreshed();
}