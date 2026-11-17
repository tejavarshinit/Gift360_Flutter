import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/features/profile/presentation/screens/profile_details_screen.dart';

class ProfileDetailsView extends StatelessWidget {
  const ProfileDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = GoRouterState.of(context).uri.queryParameters['setup'] == '1';
    return ProfileDetailsScreen(isSetup: setup);
  }
}
