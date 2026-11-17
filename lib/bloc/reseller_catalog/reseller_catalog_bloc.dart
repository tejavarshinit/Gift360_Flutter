import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_catalog_event.dart';
import 'reseller_catalog_state.dart';

class ResellerCatalogBloc extends Bloc<ResellerCatalogEvent, ResellerCatalogState> {
  ResellerCatalogBloc() : super(const ResellerCatalogState()) {
    on<ResellerCatalogStarted>(_onStarted);
    on<ResellerCatalogRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerCatalogStarted event, Emitter<ResellerCatalogState> emit) {
    emit(state.copyWith(status: ResellerCatalogStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerCatalogRefreshed event, Emitter<ResellerCatalogState> emit) {
    emit(state.copyWith(status: ResellerCatalogStatus.ready, message: ''));
  }
}