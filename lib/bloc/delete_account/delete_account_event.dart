import 'package:equatable/equatable.dart';

sealed class DeleteAccountEvent extends Equatable {
  const DeleteAccountEvent();

  @override
  List<Object?> get props => const [];
}

class DeleteAccountStarted extends DeleteAccountEvent {
  const DeleteAccountStarted();
}

class DeleteAccountRefreshed extends DeleteAccountEvent {
  const DeleteAccountRefreshed();
}