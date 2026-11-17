import 'package:equatable/equatable.dart';

enum OffersStatus { initial, loading, ready, failure }

class OffersState extends Equatable {
  const OffersState({
    this.status = OffersStatus.initial,
    this.message = '',
  });

  final OffersStatus status;
  final String message;

  OffersState copyWith({OffersStatus? status, String? message}) {
    return OffersState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}