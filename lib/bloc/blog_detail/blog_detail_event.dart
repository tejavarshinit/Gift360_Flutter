import 'package:equatable/equatable.dart';

sealed class BlogDetailEvent extends Equatable {
  const BlogDetailEvent();

  @override
  List<Object?> get props => const [];
}

class BlogDetailStarted extends BlogDetailEvent {
  const BlogDetailStarted();
}

class BlogDetailRefreshed extends BlogDetailEvent {
  const BlogDetailRefreshed();
}