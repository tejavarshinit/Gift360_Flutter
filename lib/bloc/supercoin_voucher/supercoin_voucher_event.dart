import 'package:equatable/equatable.dart';

sealed class SupercoinVoucherEvent extends Equatable {
  const SupercoinVoucherEvent();

  @override
  List<Object?> get props => const [];
}

class SupercoinVoucherStarted extends SupercoinVoucherEvent {
  const SupercoinVoucherStarted();
}

class SupercoinVoucherRefreshed extends SupercoinVoucherEvent {
  const SupercoinVoucherRefreshed();
}