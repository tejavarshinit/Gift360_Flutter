import 'package:equatable/equatable.dart';

sealed class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => const [];
}

class OrdersStarted extends OrdersEvent {
  const OrdersStarted();
}

class OrdersRefreshed extends OrdersEvent {
  const OrdersRefreshed();
}