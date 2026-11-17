import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/rewards/rewards_bloc.dart';
import 'package:gift360/bloc/rewards/rewards_event.dart';
import 'package:gift360/bloc/rewards/rewards_state.dart';
import 'package:gift360/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class RewardsView extends StatelessWidget {
  const RewardsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<RewardsBloc, RewardsEvent, RewardsState>(
      create: RewardsBloc.new,
      started: const RewardsStarted(),
      maxContentWidth: 440,
      child: const RewardsScreen(),
    );
  }
}
