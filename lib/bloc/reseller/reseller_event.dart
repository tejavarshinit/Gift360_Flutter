import 'package:equatable/equatable.dart';

sealed class ResellerEvent extends Equatable {
  const ResellerEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerStarted extends ResellerEvent {
  const ResellerStarted();
}

class ResellerRefreshed extends ResellerEvent {
  const ResellerRefreshed();
}