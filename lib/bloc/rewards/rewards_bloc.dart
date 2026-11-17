import 'package:flutter_bloc/flutter_bloc.dart';

import 'rewards_event.dart';
import 'rewards_state.dart';

class RewardsBloc extends Bloc<RewardsEvent, RewardsState> {
  RewardsBloc() : super(const RewardsState()) {
    on<RewardsStarted>(_onStarted);
    on<RewardsRefreshed>(_onRefreshed);
  }

  void _onStarted(RewardsStarted event, Emitter<RewardsState> emit) {
    emit(state.copyWith(status: RewardsStatus.ready, message: ''));
  }

  void _onRefreshed(RewardsRefreshed event, Emitter<RewardsState> emit) {
    emit(state.copyWith(status: RewardsStatus.ready, message: ''));
  }
}