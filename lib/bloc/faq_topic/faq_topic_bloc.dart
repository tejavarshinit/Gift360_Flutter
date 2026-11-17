import 'package:flutter_bloc/flutter_bloc.dart';

import 'faq_topic_event.dart';
import 'faq_topic_state.dart';

class FaqTopicBloc extends Bloc<FaqTopicEvent, FaqTopicState> {
  FaqTopicBloc() : super(const FaqTopicState()) {
    on<FaqTopicStarted>(_onStarted);
    on<FaqTopicRefreshed>(_onRefreshed);
  }

  void _onStarted(FaqTopicStarted event, Emitter<FaqTopicState> emit) {
    emit(state.copyWith(status: FaqTopicStatus.ready, message: ''));
  }

  void _onRefreshed(FaqTopicRefreshed event, Emitter<FaqTopicState> emit) {
    emit(state.copyWith(status: FaqTopicStatus.ready, message: ''));
  }
}