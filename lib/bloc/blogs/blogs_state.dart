import 'package:equatable/equatable.dart';

enum BlogsStatus { initial, loading, ready, failure }

class BlogsState extends Equatable {
  const BlogsState({
    this.status = BlogsStatus.initial,
    this.message = '',
  });

  final BlogsStatus status;
  final String message;

  BlogsState copyWith({BlogsStatus? status, String? message}) {
    return BlogsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}