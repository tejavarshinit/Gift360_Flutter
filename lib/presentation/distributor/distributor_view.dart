import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/distributor/distributor_bloc.dart';
import 'package:gift360/bloc/distributor/distributor_event.dart';
import 'package:gift360/bloc/distributor/distributor_state.dart';
import 'package:gift360/features/landing/presentation/screens/distributor_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class DistributorView extends StatelessWidget {
  const DistributorView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<DistributorBloc, DistributorEvent, DistributorState>(
      create: DistributorBloc.new,
      started: const DistributorStarted(),
      maxContentWidth: 840,
      child: const DistributorScreen(),
    );
  }
}