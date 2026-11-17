import 'package:equatable/equatable.dart';

enum ResellerCatalogStatus { initial, loading, ready, failure }

class ResellerCatalogState extends Equatable {
  const ResellerCatalogState({
    this.status = ResellerCatalogStatus.initial,
    this.message = '',
  });

  final ResellerCatalogStatus status;
  final String message;

  ResellerCatalogState copyWith({ResellerCatalogStatus? status, String? message}) {
    return ResellerCatalogState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}