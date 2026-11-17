import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_order_details/reseller_order_details_bloc.dart';
import 'package:gift360/bloc/reseller_order_details/reseller_order_details_event.dart';
import 'package:gift360/bloc/reseller_order_details/reseller_order_details_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_order_details_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerOrderDetailsView extends StatelessWidget {
  const ResellerOrderDetailsView({
    super.key,
    required this.details,
    this.createdAt,
    this.avatarInitial = 'R',
    this.onHome,
    this.onProfile,
  });

  final Map<String, dynamic> details;
  final String? createdAt;
  final String avatarInitial;
  final VoidCallback? onHome;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<
      ResellerOrderDetailsBloc,
      ResellerOrderDetailsEvent,
      ResellerOrderDetailsState
    >(
      create: ResellerOrderDetailsBloc.new,
      started: const ResellerOrderDetailsStarted(),
      maxContentWidth: 960,
      child: ResellerOrderDetailsScreen(
        details: details,
        createdAt: createdAt,
        avatarInitial: avatarInitial,
        onHome: onHome,
        onProfile: onProfile,
      ),
    );
  }
}