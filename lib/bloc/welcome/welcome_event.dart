import 'package:equatable/equatable.dart';

sealed class WelcomeEvent extends Equatable {
  const WelcomeEvent();

  @override
  List<Object?> get props => const [];
}

class WelcomeStarted extends WelcomeEvent {
  const WelcomeStarted();
}

class WelcomeRefreshed extends WelcomeEvent {
  const WelcomeRefreshed();
}