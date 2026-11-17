import 'package:equatable/equatable.dart';

sealed class ResellerOrderDetailsEvent extends Equatable {
  const ResellerOrderDetailsEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerOrderDetailsStarted extends ResellerOrderDetailsEvent {
  const ResellerOrderDetailsStarted();
}

class ResellerOrderDetailsRefreshed extends ResellerOrderDetailsEvent {
  const ResellerOrderDetailsRefreshed();
}