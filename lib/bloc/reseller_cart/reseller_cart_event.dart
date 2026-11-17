import 'package:equatable/equatable.dart';

sealed class ResellerCartEvent extends Equatable {
  const ResellerCartEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerCartStarted extends ResellerCartEvent {
  const ResellerCartStarted();
}

class ResellerCartRefreshed extends ResellerCartEvent {
  const ResellerCartRefreshed();
}