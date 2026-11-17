import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_dashboard/reseller_dashboard_bloc.dart';
import 'package:gift360/bloc/reseller_dashboard/reseller_dashboard_event.dart';
import 'package:gift360/bloc/reseller_dashboard/reseller_dashboard_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_dashboard_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerDashboardView extends StatelessWidget {
  const ResellerDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResellerDashboardBloc, ResellerDashboardEvent, ResellerDashboardState>(
      create: ResellerDashboardBloc.new,
      started: const ResellerDashboardStarted(),
      maxContentWidth: 1120,
      child: const ResellerDashboardScreen(),
    );
  }
}