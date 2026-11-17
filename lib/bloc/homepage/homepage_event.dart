import 'package:equatable/equatable.dart';

sealed class HomepageEvent extends Equatable {
  const HomepageEvent();

  @override
  List<Object?> get props => const [];
}

class HomepageStarted extends HomepageEvent {
  const HomepageStarted();
}

class HomepageRefreshed extends HomepageEvent {
  const HomepageRefreshed();
}