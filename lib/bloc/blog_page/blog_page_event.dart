import 'package:equatable/equatable.dart';

sealed class BlogPageEvent extends Equatable {
  const BlogPageEvent();

  @override
  List<Object?> get props => const [];
}

class BlogPageStarted extends BlogPageEvent {
  const BlogPageStarted();
}

class BlogPageRefreshed extends BlogPageEvent {
  const BlogPageRefreshed();
}