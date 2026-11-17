import 'package:equatable/equatable.dart';

enum HomepageStatus { initial, loading, ready, failure }

class HomepageState extends Equatable {
  const HomepageState({
    this.status = HomepageStatus.initial,
    this.message = '',
  });

  final HomepageStatus status;
  final String message;

  HomepageState copyWith({HomepageStatus? status, String? message}) {
    return HomepageState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}