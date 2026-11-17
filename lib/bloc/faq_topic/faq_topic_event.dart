import 'package:equatable/equatable.dart';

sealed class FaqTopicEvent extends Equatable {
  const FaqTopicEvent();

  @override
  List<Object?> get props => const [];
}

class FaqTopicStarted extends FaqTopicEvent {
  const FaqTopicStarted();
}

class FaqTopicRefreshed extends FaqTopicEvent {
  const FaqTopicRefreshed();
}