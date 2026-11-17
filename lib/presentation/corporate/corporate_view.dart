import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/corporate/corporate_bloc.dart';
import 'package:gift360/bloc/corporate/corporate_event.dart';
import 'package:gift360/bloc/corporate/corporate_state.dart';
import 'package:gift360/features/landing/presentation/screens/corporate_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class CorporateView extends StatelessWidget {
  const CorporateView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<CorporateBloc, CorporateEvent, CorporateState>(
      create: CorporateBloc.new,
      started: const CorporateStarted(),
      maxContentWidth: 840,
      child: const CorporateScreen(),
    );
  }
}