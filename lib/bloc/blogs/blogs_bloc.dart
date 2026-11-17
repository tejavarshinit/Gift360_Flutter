import 'package:flutter_bloc/flutter_bloc.dart';

import 'blogs_event.dart';
import 'blogs_state.dart';

class BlogsBloc extends Bloc<BlogsEvent, BlogsState> {
  BlogsBloc() : super(const BlogsState()) {
    on<BlogsStarted>(_onStarted);
    on<BlogsRefreshed>(_onRefreshed);
  }

  void _onStarted(BlogsStarted event, Emitter<BlogsState> emit) {
    emit(state.copyWith(status: BlogsStatus.ready, message: ''));
  }

  void _onRefreshed(BlogsRefreshed event, Emitter<BlogsState> emit) {
    emit(state.copyWith(status: BlogsStatus.ready, message: ''));
  }
}