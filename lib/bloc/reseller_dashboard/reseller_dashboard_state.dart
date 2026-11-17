import 'package:equatable/equatable.dart';

enum ResellerDashboardStatus { initial, loading, ready, failure }

class ResellerDashboardState extends Equatable {
  const ResellerDashboardState({
    this.status = ResellerDashboardStatus.initial,
    this.message = '',
  });

  final ResellerDashboardStatus status;
  final String message;

  ResellerDashboardState copyWith({ResellerDashboardStatus? status, String? message}) {
    return ResellerDashboardState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}