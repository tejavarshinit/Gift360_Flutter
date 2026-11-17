import 'package:equatable/equatable.dart';

sealed class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => const [];
}

class PaymentStarted extends PaymentEvent {
  const PaymentStarted();
}

class PaymentRefreshed extends PaymentEvent {
  const PaymentRefreshed();
}