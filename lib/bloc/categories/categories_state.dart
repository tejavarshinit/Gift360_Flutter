import 'package:equatable/equatable.dart';

enum CategoriesStatus { initial, loading, ready, failure }

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.message = '',
  });

  final CategoriesStatus status;
  final String message;

  CategoriesState copyWith({CategoriesStatus? status, String? message}) {
    return CategoriesState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}