import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/privacy/privacy_bloc.dart';
import 'package:gift360/bloc/privacy/privacy_event.dart';
import 'package:gift360/bloc/privacy/privacy_state.dart';
import 'package:gift360/features/legal/presentation/screens/privacy_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<PrivacyBloc, PrivacyEvent, PrivacyState>(
      create: PrivacyBloc.new,
      started: const PrivacyStarted(),
      maxContentWidth: 840,
      child: const PrivacyScreen(),
    );
  }
}