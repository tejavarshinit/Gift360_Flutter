import 'package:equatable/equatable.dart';

enum BlogDetailStatus { initial, loading, ready, failure }

class BlogDetailState extends Equatable {
  const BlogDetailState({
    this.status = BlogDetailStatus.initial,
    this.message = '',
  });

  final BlogDetailStatus status;
  final String message;

  BlogDetailState copyWith({BlogDetailStatus? status, String? message}) {
    return BlogDetailState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}