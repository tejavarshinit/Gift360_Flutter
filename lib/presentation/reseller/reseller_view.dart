import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller/reseller_bloc.dart';
import 'package:gift360/bloc/reseller/reseller_event.dart';
import 'package:gift360/bloc/reseller/reseller_state.dart';
import 'package:gift360/features/landing/presentation/screens/reseller_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerView extends StatelessWidget {
  const ResellerView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResellerBloc, ResellerEvent, ResellerState>(
      create: ResellerBloc.new,
      started: const ResellerStarted(),
      maxContentWidth: 840,
      child: const ResellerScreen(),
    );
  }
}