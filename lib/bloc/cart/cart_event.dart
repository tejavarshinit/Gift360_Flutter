import 'package:equatable/equatable.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => const [];
}

class CartStarted extends CartEvent {
  const CartStarted();
}

class CartRefreshed extends CartEvent {
  const CartRefreshed();
}