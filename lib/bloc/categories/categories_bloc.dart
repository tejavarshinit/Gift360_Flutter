import 'package:flutter_bloc/flutter_bloc.dart';

import 'categories_event.dart';
import 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc() : super(const CategoriesState()) {
    on<CategoriesStarted>(_onStarted);
    on<CategoriesRefreshed>(_onRefreshed);
  }

  void _onStarted(CategoriesStarted event, Emitter<CategoriesState> emit) {
    emit(state.copyWith(status: CategoriesStatus.ready, message: ''));
  }

  void _onRefreshed(CategoriesRefreshed event, Emitter<CategoriesState> emit) {
    emit(state.copyWith(status: CategoriesStatus.ready, message: ''));
  }
}