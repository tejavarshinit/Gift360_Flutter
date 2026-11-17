import 'package:equatable/equatable.dart';

sealed class ResellerCatalogEvent extends Equatable {
  const ResellerCatalogEvent();

  @override
  List<Object?> get props => const [];
}

class ResellerCatalogStarted extends ResellerCatalogEvent {
  const ResellerCatalogStarted();
}

class ResellerCatalogRefreshed extends ResellerCatalogEvent {
  const ResellerCatalogRefreshed();
}