import 'package:flutter_bloc/flutter_bloc.dart';

import 'blog_page_event.dart';
import 'blog_page_state.dart';

class BlogPageBloc extends Bloc<BlogPageEvent, BlogPageState> {
  BlogPageBloc() : super(const BlogPageState()) {
    on<BlogPageStarted>(_onStarted);
    on<BlogPageRefreshed>(_onRefreshed);
  }

  void _onStarted(BlogPageStarted event, Emitter<BlogPageState> emit) {
    emit(state.copyWith(status: BlogPageStatus.ready, message: ''));
  }

  void _onRefreshed(BlogPageRefreshed event, Emitter<BlogPageState> emit) {
    emit(state.copyWith(status: BlogPageStatus.ready, message: ''));
  }
}