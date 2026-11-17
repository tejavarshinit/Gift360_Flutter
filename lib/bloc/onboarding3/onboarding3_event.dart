import 'package:equatable/equatable.dart';

sealed class Onboarding3Event extends Equatable {
  const Onboarding3Event();

  @override
  List<Object?> get props => const [];
}

class Onboarding3Started extends Onboarding3Event {
  const Onboarding3Started();
}

class Onboarding3Refreshed extends Onboarding3Event {
  const Onboarding3Refreshed();
}