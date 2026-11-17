import 'package:equatable/equatable.dart';

sealed class Onboarding1Event extends Equatable {
  const Onboarding1Event();

  @override
  List<Object?> get props => const [];
}

class Onboarding1Started extends Onboarding1Event {
  const Onboarding1Started();
}

class Onboarding1Refreshed extends Onboarding1Event {
  const Onboarding1Refreshed();
}