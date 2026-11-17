import 'package:equatable/equatable.dart';

enum DistributorStatus { initial, loading, ready, failure }

class DistributorState extends Equatable {
  const DistributorState({
    this.status = DistributorStatus.initial,
    this.message = '',
  });

  final DistributorStatus status;
  final String message;

  DistributorState copyWith({DistributorStatus? status, String? message}) {
    return DistributorState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}