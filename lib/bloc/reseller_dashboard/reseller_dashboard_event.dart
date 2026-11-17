import 'package:equatable/equatable.dart';

sealed class ResellerDashboardEvent extends Equatable {
  const ResellerDashboardEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerDashboardStarted extends ResellerDashboardEvent {
  const ResellerDashboardStarted();
}

class ResellerDashboardRefreshed extends ResellerDashboardEvent {
  const ResellerDashboardRefreshed();
}