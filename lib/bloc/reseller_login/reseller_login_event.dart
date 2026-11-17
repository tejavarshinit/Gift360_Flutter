import 'package:equatable/equatable.dart';

sealed class ResellerLoginEvent extends Equatable {
  const ResellerLoginEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerLoginStarted extends ResellerLoginEvent {
  const ResellerLoginStarted();
}

class ResellerLoginRefreshed extends ResellerLoginEvent {
  const ResellerLoginRefreshed();
}