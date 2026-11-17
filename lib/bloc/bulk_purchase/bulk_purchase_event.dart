import 'package:equatable/equatable.dart';

sealed class BulkPurchaseEvent extends Equatable {
  const BulkPurchaseEvent();

  @override
  List<Object?> get props => const [];
}

class BulkPurchaseStarted extends BulkPurchaseEvent {
  const BulkPurchaseStarted();
}

class BulkPurchaseRefreshed extends BulkPurchaseEvent {
  const BulkPurchaseRefreshed();
}