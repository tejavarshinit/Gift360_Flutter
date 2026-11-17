import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileRefreshed>(_onRefreshed);
  }

  void _onStarted(ProfileStarted event, Emitter<ProfileState> emit) {
    emit(state.copyWith(status: ProfileStatus.ready, message: ''));
  }

  void _onRefreshed(ProfileRefreshed event, Emitter<ProfileState> emit) {
    emit(state.copyWith(status: ProfileStatus.ready, message: ''));
  }
}