import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/homepage/homepage_bloc.dart';
import 'package:gift360/bloc/homepage/homepage_event.dart';
import 'package:gift360/bloc/homepage/homepage_state.dart';
import 'package:gift360/features/home/presentation/screens/home_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class HomepageView extends StatelessWidget {
  const HomepageView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<HomepageBloc, HomepageEvent, HomepageState>(
      create: HomepageBloc.new,
      started: const HomepageStarted(),
      maxContentWidth: 1120,
      child: const HomeScreen(),
    );
  }
}