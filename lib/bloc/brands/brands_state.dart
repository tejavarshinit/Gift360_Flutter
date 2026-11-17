import 'package:equatable/equatable.dart';

enum BrandsStatus { initial, loading, ready, failure }

class BrandsState extends Equatable {
  const BrandsState({
    this.status = BrandsStatus.initial,
    this.message = '',
  });

  final BrandsStatus status;
  final String message;

  BrandsState copyWith({BrandsStatus? status, String? message}) {
    return BrandsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}