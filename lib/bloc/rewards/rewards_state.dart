import 'package:equatable/equatable.dart';

enum RewardsStatus { initial, loading, ready, failure }

class RewardsState extends Equatable {
  const RewardsState({
    this.status = RewardsStatus.initial,
    this.message = '',
  });

  final RewardsStatus status;
  final String message;

  RewardsState copyWith({RewardsStatus? status, String? message}) {
    return RewardsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}