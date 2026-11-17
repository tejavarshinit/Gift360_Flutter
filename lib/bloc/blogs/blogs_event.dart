import 'package:equatable/equatable.dart';

sealed class BlogsEvent extends Equatable {
  const BlogsEvent();

  @override
  List<Object?> get props => const [];
}

class BlogsStarted extends BlogsEvent {
  const BlogsStarted();
}

class BlogsRefreshed extends BlogsEvent {
  const BlogsRefreshed();
}