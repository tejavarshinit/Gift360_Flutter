import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/offers/offers_bloc.dart';
import 'package:gift360/bloc/offers/offers_event.dart';
import 'package:gift360/bloc/offers/offers_state.dart';
import 'package:gift360/features/offers/presentation/screens/offers_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class OffersView extends StatelessWidget {
  const OffersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<OffersBloc, OffersEvent, OffersState>(
      create: OffersBloc.new,
      started: const OffersStarted(),
      maxContentWidth: 1120,
      child: const OffersScreen(),
    );
  }
}