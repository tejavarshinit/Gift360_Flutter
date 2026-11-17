import 'package:equatable/equatable.dart';

sealed class SpinWheelEvent extends Equatable {
  const SpinWheelEvent();

  @override
  List<Object?> get props => const [];
}

class SpinWheelStarted extends SpinWheelEvent {
  const SpinWheelStarted();
}

class SpinWheelRefreshed extends SpinWheelEvent {
  const SpinWheelRefreshed();
}