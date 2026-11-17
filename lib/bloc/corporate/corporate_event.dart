import 'package:equatable/equatable.dart';

sealed class CorporateEvent extends Equatable {
  const CorporateEvent();

  @override
  List<Object?> get props => const [];
}

class CorporateStarted extends CorporateEvent {
  const CorporateStarted();
}

class CorporateRefreshed extends CorporateEvent {
  const CorporateRefreshed();
}