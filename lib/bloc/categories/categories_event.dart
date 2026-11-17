import 'package:equatable/equatable.dart';

sealed class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => const [];
}

class CategoriesStarted extends CategoriesEvent {
  const CategoriesStarted();
}

class CategoriesRefreshed extends CategoriesEvent {
  const CategoriesRefreshed();
}