import 'package:equatable/equatable.dart';

sealed class FaqEvent extends Equatable {
  const FaqEvent();

  @override
  List<Object?> get props => const [];
}

class FaqStarted extends FaqEvent {
  const FaqStarted();
}

class FaqRefreshed extends FaqEvent {
  const FaqRefreshed();
}