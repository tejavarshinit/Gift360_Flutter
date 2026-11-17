import 'package:equatable/equatable.dart';

enum CorporateStatus { initial, loading, ready, failure }

class CorporateState extends Equatable {
  const CorporateState({
    this.status = CorporateStatus.initial,
    this.message = '',
  });

  final CorporateStatus status;
  final String message;

  CorporateState copyWith({CorporateStatus? status, String? message}) {
    return CorporateState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}