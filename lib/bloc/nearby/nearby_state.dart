import 'package:equatable/equatable.dart';

enum NearbyStatus { initial, loading, ready, failure }

class NearbyState extends Equatable {
  const NearbyState({
    this.status = NearbyStatus.initial,
    this.message = '',
  });

  final NearbyStatus status;
  final String message;

  NearbyState copyWith({NearbyStatus? status, String? message}) {
    return NearbyState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}