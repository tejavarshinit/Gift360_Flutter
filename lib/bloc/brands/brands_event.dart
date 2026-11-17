import 'package:equatable/equatable.dart';

sealed class BrandsEvent extends Equatable {
  const BrandsEvent();

  @override
  List<Object?> get props => const [];
}

class BrandsStarted extends BrandsEvent {
  const BrandsStarted();
}

class BrandsRefreshed extends BrandsEvent {
  const BrandsRefreshed();
}