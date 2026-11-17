import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/faq/faq_bloc.dart';
import 'package:gift360/bloc/faq/faq_event.dart';
import 'package:gift360/bloc/faq/faq_state.dart';
import 'package:gift360/features/faq/presentation/screens/faq_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class FaqView extends StatelessWidget {
  const FaqView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<FaqBloc, FaqEvent, FaqState>(
      create: FaqBloc.new,
      started: const FaqStarted(),
      maxContentWidth: 840,
      child: const FaqScreen(),
    );
  }
}