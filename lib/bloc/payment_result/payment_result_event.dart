import 'package:equatable/equatable.dart';

sealed class PaymentResultEvent extends Equatable {
  const PaymentResultEvent();

  @override
  List<Object?> get props => const [];
}

class PaymentResultStarted extends PaymentResultEvent {
  const PaymentResultStarted();
}

class PaymentResultRefreshed extends PaymentResultEvent {
  const PaymentResultRefreshed();
}