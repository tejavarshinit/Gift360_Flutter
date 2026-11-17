import 'package:equatable/equatable.dart';

enum BlogPageStatus { initial, loading, ready, failure }

class BlogPageState extends Equatable {
  const BlogPageState({
    this.status = BlogPageStatus.initial,
    this.message = '',
  });

  final BlogPageStatus status;
  final String message;

  BlogPageState copyWith({BlogPageStatus? status, String? message}) {
    return BlogPageState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}