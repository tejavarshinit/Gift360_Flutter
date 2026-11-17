import 'package:equatable/equatable.dart';

sealed class Onboarding2Event extends Equatable {
  const Onboarding2Event();

  @override
  List<Object?> get props => const [];
}

class Onboarding2Started extends Onboarding2Event {
  const Onboarding2Started();
}

class Onboarding2Refreshed extends Onboarding2Event {
  const Onboarding2Refreshed();
}