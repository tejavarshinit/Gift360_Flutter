import 'package:flutter_bloc/flutter_bloc.dart';

import 'delete_account_event.dart';
import 'delete_account_state.dart';

class DeleteAccountBloc extends Bloc<DeleteAccountEvent, DeleteAccountState> {
  DeleteAccountBloc() : super(const DeleteAccountState()) {
    on<DeleteAccountStarted>(_onStarted);
    on<DeleteAccountRefreshed>(_onRefreshed);
  }

  void _onStarted(DeleteAccountStarted event, Emitter<DeleteAccountState> emit) {
    emit(state.copyWith(status: DeleteAccountStatus.ready, message: ''));
  }

  void _onRefreshed(DeleteAccountRefreshed event, Emitter<DeleteAccountState> emit) {
    emit(state.copyWith(status: DeleteAccountStatus.ready, message: ''));
  }
}