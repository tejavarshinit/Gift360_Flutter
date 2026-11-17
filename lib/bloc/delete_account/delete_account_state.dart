import 'package:equatable/equatable.dart';

enum DeleteAccountStatus { initial, loading, ready, failure }

class DeleteAccountState extends Equatable {
  const DeleteAccountState({
    this.status = DeleteAccountStatus.initial,
    this.message = '',
  });

  final DeleteAccountStatus status;
  final String message;

  DeleteAccountState copyWith({DeleteAccountStatus? status, String? message}) {
    return DeleteAccountState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}