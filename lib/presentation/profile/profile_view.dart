import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/profile/profile_bloc.dart';
import 'package:gift360/bloc/profile/profile_event.dart';
import 'package:gift360/bloc/profile/profile_state.dart';
import 'package:gift360/features/profile/presentation/screens/profile_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ProfileBloc, ProfileEvent, ProfileState>(
      create: ProfileBloc.new,
      started: const ProfileStarted(),
      maxContentWidth: 840,
      child: const ProfileScreen(),
    );
  }
}