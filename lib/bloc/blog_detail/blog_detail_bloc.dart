import 'package:flutter_bloc/flutter_bloc.dart';

import 'blog_detail_event.dart';
import 'blog_detail_state.dart';

class BlogDetailBloc extends Bloc<BlogDetailEvent, BlogDetailState> {
  BlogDetailBloc() : super(const BlogDetailState()) {
    on<BlogDetailStarted>(_onStarted);
    on<BlogDetailRefreshed>(_onRefreshed);
  }

  void _onStarted(BlogDetailStarted event, Emitter<BlogDetailState> emit) {
    emit(state.copyWith(status: BlogDetailStatus.ready, message: ''));
  }

  void _onRefreshed(BlogDetailRefreshed event, Emitter<BlogDetailState> emit) {
    emit(state.copyWith(status: BlogDetailStatus.ready, message: ''));
  }
}