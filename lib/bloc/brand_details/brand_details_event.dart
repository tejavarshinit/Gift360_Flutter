import 'package:equatable/equatable.dart';

sealed class BrandDetailsEvent extends Equatable {
  const BrandDetailsEvent();

  @override
  List<Object?> get props => const [];
}

class BrandDetailsStarted extends BrandDetailsEvent {
  const BrandDetailsStarted();
}

class BrandDetailsRefreshed extends BrandDetailsEvent {
  const BrandDetailsRefreshed();
}