import 'package:equatable/equatable.dart';

sealed class PaymentWebviewEvent extends Equatable {
  const PaymentWebviewEvent();

  @override
  List<Object?> get props => const [];
}

class PaymentWebviewStarted extends PaymentWebviewEvent {
  const PaymentWebviewStarted();
}

class PaymentWebviewRefreshed extends PaymentWebviewEvent {
  const PaymentWebviewRefreshed();
}