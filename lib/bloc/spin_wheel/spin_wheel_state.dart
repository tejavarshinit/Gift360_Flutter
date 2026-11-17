import 'package:equatable/equatable.dart';

enum SpinWheelStatus { initial, loading, ready, failure }

class SpinWheelState extends Equatable {
  const SpinWheelState({
    this.status = SpinWheelStatus.initial,
    this.message = '',
  });

  final SpinWheelStatus status;
  final String message;

  SpinWheelState copyWith({SpinWheelStatus? status, String? message}) {
    return SpinWheelState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}