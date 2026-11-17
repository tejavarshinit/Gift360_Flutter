import 'package:equatable/equatable.dart';

sealed class MyOrdersEvent extends Equatable {
  const MyOrdersEvent();

  @override
  List<Object?> get props => const [];
}

class MyOrdersStarted extends MyOrdersEvent {
  const MyOrdersStarted();
}

class MyOrdersRefreshed extends MyOrdersEvent {
  const MyOrdersRefreshed();
}