import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/brands/brands_bloc.dart';
import 'package:gift360/bloc/brands/brands_event.dart';
import 'package:gift360/bloc/brands/brands_state.dart';
import 'package:gift360/features/brands/presentation/screens/brands_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BrandsView extends StatelessWidget {
  const BrandsView({
    super.key,
    this.initialSearch,
    this.initialCategory,
    this.initialSuperCoinsOnly = false,
    this.initialDiscountRanges = const [],
  });

  final String? initialSearch;
  final String? initialCategory;
  final bool initialSuperCoinsOnly;
  final List<String> initialDiscountRanges;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BrandsBloc, BrandsEvent, BrandsState>(
      create: BrandsBloc.new,
      started: const BrandsStarted(),
      maxContentWidth: 1120,
      child: BrandsScreen(
        initialSearch: initialSearch,
        initialCategory: initialCategory,
        initialSuperCoinsOnly: initialSuperCoinsOnly,
        initialDiscountRanges: initialDiscountRanges,
      ),
    );
  }
}