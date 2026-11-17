import 'package:equatable/equatable.dart';

enum SupercoinVoucherStatus { initial, loading, ready, failure }

class SupercoinVoucherState extends Equatable {
  const SupercoinVoucherState({
    this.status = SupercoinVoucherStatus.initial,
    this.message = '',
  });

  final SupercoinVoucherStatus status;
  final String message;

  SupercoinVoucherState copyWith({SupercoinVoucherStatus? status, String? message}) {
    return SupercoinVoucherState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}