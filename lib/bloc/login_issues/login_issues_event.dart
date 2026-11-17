import 'package:equatable/equatable.dart';

sealed class LoginIssuesEvent extends Equatable {
  const LoginIssuesEvent();

  @override
  List<Object?> get props => const [];
}

class LoginIssuesStarted extends LoginIssuesEvent {
  const LoginIssuesStarted();
}

class LoginIssuesRefreshed extends LoginIssuesEvent {
  const LoginIssuesRefreshed();
}