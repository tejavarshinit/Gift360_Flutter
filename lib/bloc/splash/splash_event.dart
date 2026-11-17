import 'package:equatable/equatable.dart';

sealed class SplashEvent extends Equatable {
  const SplashEvent();

  @override
  List<Object?> get props => const [];
}

class SplashStarted extends SplashEvent {
  const SplashStarted();
}

class SplashRefreshed extends SplashEvent {
  const SplashRefreshed();
}