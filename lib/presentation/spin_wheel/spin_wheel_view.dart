import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/spin_wheel/spin_wheel_bloc.dart';
import 'package:gift360/bloc/spin_wheel/spin_wheel_event.dart';
import 'package:gift360/bloc/spin_wheel/spin_wheel_state.dart';
import 'package:gift360/features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class SpinWheelView extends StatelessWidget {
  const SpinWheelView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<SpinWheelBloc, SpinWheelEvent, SpinWheelState>(
      create: SpinWheelBloc.new,
      started: const SpinWheelStarted(),
      
      child: const SpinWheelScreen(),
    );
  }
}