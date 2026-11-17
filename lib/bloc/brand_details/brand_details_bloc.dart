import 'package:flutter_bloc/flutter_bloc.dart';

import 'brand_details_event.dart';
import 'brand_details_state.dart';

class BrandDetailsBloc extends Bloc<BrandDetailsEvent, BrandDetailsState> {
  BrandDetailsBloc() : super(const BrandDetailsState()) {
    on<BrandDetailsStarted>(_onStarted);
    on<BrandDetailsRefreshed>(_onRefreshed);
  }

  void _onStarted(BrandDetailsStarted event, Emitter<BrandDetailsState> emit) {
    emit(state.copyWith(status: BrandDetailsStatus.ready, message: ''));
  }

  void _onRefreshed(BrandDetailsRefreshed event, Emitter<BrandDetailsState> emit) {
    emit(state.copyWith(status: BrandDetailsStatus.ready, message: ''));
  }
}