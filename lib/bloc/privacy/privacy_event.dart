import 'package:equatable/equatable.dart';

sealed class PrivacyEvent extends Equatable {
  const PrivacyEvent();

  @override
  List<Object?> get props => const [];
}

class PrivacyStarted extends PrivacyEvent {
  const PrivacyStarted();
}

class PrivacyRefreshed extends PrivacyEvent {
  const PrivacyRefreshed();
}