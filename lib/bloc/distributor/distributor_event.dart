import 'package:equatable/equatable.dart';

sealed class DistributorEvent extends Equatable {
  const DistributorEvent();

  @override
  List<Object?> get props => const [];
}

class DistributorStarted extends DistributorEvent {
  const DistributorStarted();
}

class DistributorRefreshed extends DistributorEvent {
  const DistributorRefreshed();
}