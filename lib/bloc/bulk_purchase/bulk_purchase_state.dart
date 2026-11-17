import 'package:equatable/equatable.dart';

enum BulkPurchaseStatus { initial, loading, ready, failure }

class BulkPurchaseState extends Equatable {
  const BulkPurchaseState({
    this.status = BulkPurchaseStatus.initial,
    this.message = '',
  });

  final BulkPurchaseStatus status;
  final String message;

  BulkPurchaseState copyWith({BulkPurchaseStatus? status, String? message}) {
    return BulkPurchaseState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}