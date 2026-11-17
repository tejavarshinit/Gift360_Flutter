import 'package:equatable/equatable.dart';

enum ResellerLoginStatus { initial, loading, ready, failure }

class ResellerLoginState extends Equatable {
  const ResellerLoginState({
    this.status = ResellerLoginStatus.initial,
    this.message = '',
  });

  final ResellerLoginStatus status;
  final String message;

  ResellerLoginState copyWith({ResellerLoginStatus? status, String? message}) {
    return ResellerLoginState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}