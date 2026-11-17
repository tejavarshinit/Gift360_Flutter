import 'package:equatable/equatable.dart';

enum FaqStatus { initial, loading, ready, failure }

class FaqState extends Equatable {
  const FaqState({
    this.status = FaqStatus.initial,
    this.message = '',
  });

  final FaqStatus status;
  final String message;

  FaqState copyWith({FaqStatus? status, String? message}) {
    return FaqState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}