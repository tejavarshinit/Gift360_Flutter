import 'package:equatable/equatable.dart';

enum TermsStatus { initial, loading, ready, failure }

class TermsState extends Equatable {
  const TermsState({
    this.status = TermsStatus.initial,
    this.message = '',
  });

  final TermsStatus status;
  final String message;

  TermsState copyWith({TermsStatus? status, String? message}) {
    return TermsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}