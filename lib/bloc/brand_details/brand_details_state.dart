import 'package:equatable/equatable.dart';

enum BrandDetailsStatus { initial, loading, ready, failure }

class BrandDetailsState extends Equatable {
  const BrandDetailsState({
    this.status = BrandDetailsStatus.initial,
    this.message = '',
  });

  final BrandDetailsStatus status;
  final String message;

  BrandDetailsState copyWith({BrandDetailsStatus? status, String? message}) {
    return BrandDetailsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}