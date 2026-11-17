import 'package:equatable/equatable.dart';

sealed class TermsEvent extends Equatable {
  const TermsEvent();

  @override
  List<Object?> get props => const [];
}

class TermsStarted extends TermsEvent {
  const TermsStarted();
}

class TermsRefreshed extends TermsEvent {
  const TermsRefreshed();
}