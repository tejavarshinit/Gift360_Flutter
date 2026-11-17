import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/terms/terms_bloc.dart';
import 'package:gift360/bloc/terms/terms_event.dart';
import 'package:gift360/bloc/terms/terms_state.dart';
import 'package:gift360/features/legal/presentation/screens/terms_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class TermsView extends StatelessWidget {
  const TermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<TermsBloc, TermsEvent, TermsState>(
      create: TermsBloc.new,
      started: const TermsStarted(),
      maxContentWidth: 840,
      child: const TermsScreen(),
    );
  }
}