import 'package:equatable/equatable.dart';

sealed class RefundEvent extends Equatable {
  const RefundEvent();

  @override
  List<Object?> get props => const [];
}

class RefundStarted extends RefundEvent {
  const RefundStarted();
}

class RefundRefreshed extends RefundEvent {
  const RefundRefreshed();
}