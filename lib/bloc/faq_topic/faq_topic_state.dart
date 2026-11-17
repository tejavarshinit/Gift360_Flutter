import 'package:equatable/equatable.dart';

enum FaqTopicStatus { initial, loading, ready, failure }

class FaqTopicState extends Equatable {
  const FaqTopicState({
    this.status = FaqTopicStatus.initial,
    this.message = '',
  });

  final FaqTopicStatus status;
  final String message;

  FaqTopicState copyWith({FaqTopicStatus? status, String? message}) {
    return FaqTopicState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}