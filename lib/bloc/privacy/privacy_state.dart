import 'package:equatable/equatable.dart';

enum PrivacyStatus { initial, loading, ready, failure }

class PrivacyState extends Equatable {
  const PrivacyState({
    this.status = PrivacyStatus.initial,
    this.message = '',
  });

  final PrivacyStatus status;
  final String message;

  PrivacyState copyWith({PrivacyStatus? status, String? message}) {
    return PrivacyState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}