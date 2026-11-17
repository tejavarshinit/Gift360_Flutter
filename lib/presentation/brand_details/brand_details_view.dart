import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/brand_details/brand_details_bloc.dart';
import 'package:gift360/bloc/brand_details/brand_details_event.dart';
import 'package:gift360/bloc/brand_details/brand_details_state.dart';
import 'package:gift360/features/brands/presentation/screens/brand_details_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BrandDetailsView extends StatelessWidget {
  const BrandDetailsView({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BrandDetailsBloc, BrandDetailsEvent, BrandDetailsState>(
      create: BrandDetailsBloc.new,
      started: const BrandDetailsStarted(),
      maxContentWidth: 960,
      child: BrandDetailsScreen(brandId: brandId),
    );
  }
}