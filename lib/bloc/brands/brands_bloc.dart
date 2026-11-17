import 'package:flutter_bloc/flutter_bloc.dart';

import 'brands_event.dart';
import 'brands_state.dart';

class BrandsBloc extends Bloc<BrandsEvent, BrandsState> {
  BrandsBloc() : super(const BrandsState()) {
    on<BrandsStarted>(_onStarted);
    on<BrandsRefreshed>(_onRefreshed);
  }

  void _onStarted(BrandsStarted event, Emitter<BrandsState> emit) {
    emit(state.copyWith(status: BrandsStatus.ready, message: ''));
  }

  void _onRefreshed(BrandsRefreshed event, Emitter<BrandsState> emit) {
    emit(state.copyWith(status: BrandsStatus.ready, message: ''));
  }
}