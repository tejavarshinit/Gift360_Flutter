import 'package:equatable/equatable.dart';

sealed class OrderCheckoutEvent extends Equatable {
  const OrderCheckoutEvent();

  @override
  List<Object?> get props => const [];
}

class OrderCheckoutStarted extends OrderCheckoutEvent {
  const OrderCheckoutStarted();
}

class OrderCheckoutRefreshed extends OrderCheckoutEvent {
  const OrderCheckoutRefreshed();
}