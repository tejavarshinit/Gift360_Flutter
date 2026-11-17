import 'package:flutter_bloc/flutter_bloc.dart';

import 'homepage_event.dart';
import 'homepage_state.dart';

class HomepageBloc extends Bloc<HomepageEvent, HomepageState> {
  HomepageBloc() : super(const HomepageState()) {
    on<HomepageStarted>(_onStarted);
    on<HomepageRefreshed>(_onRefreshed);
  }

  void _onStarted(HomepageStarted event, Emitter<HomepageState> emit) {
    emit(state.copyWith(status: HomepageStatus.ready, message: ''));
  }

  void _onRefreshed(HomepageRefreshed event, Emitter<HomepageState> emit) {
    emit(state.copyWith(status: HomepageStatus.ready, message: ''));
  }
}