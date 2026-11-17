import 'package:equatable/equatable.dart';

sealed class NearbyEvent extends Equatable {
  const NearbyEvent();

  @override
  List<Object?> get props => const [];
}

class NearbyStarted extends NearbyEvent {
  const NearbyStarted();
}

class NearbyRefreshed extends NearbyEvent {
  const NearbyRefreshed();
}