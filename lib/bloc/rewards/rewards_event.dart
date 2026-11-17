import 'package:equatable/equatable.dart';

sealed class RewardsEvent extends Equatable {
  const RewardsEvent();

  @override
  List<Object?> get props => const [];
}

class RewardsStarted extends RewardsEvent {
  const RewardsStarted();
}

class RewardsRefreshed extends RewardsEvent {
  const RewardsRefreshed();
}