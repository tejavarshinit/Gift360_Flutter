import 'package:equatable/equatable.dart';

sealed class OffersEvent extends Equatable {
  const OffersEvent();

  @override
  List<Object?> get props => const [];
}

class OffersStarted extends OffersEvent {
  const OffersStarted();
}

class OffersRefreshed extends OffersEvent {
  const OffersRefreshed();
}