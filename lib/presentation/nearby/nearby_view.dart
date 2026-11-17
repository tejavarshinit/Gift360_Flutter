import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/nearby/nearby_bloc.dart';
import 'package:gift360/bloc/nearby/nearby_event.dart';
import 'package:gift360/bloc/nearby/nearby_state.dart';
import 'package:gift360/features/nearby/presentation/screens/nearby_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class NearbyView extends StatelessWidget {
  const NearbyView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<NearbyBloc, NearbyEvent, NearbyState>(
      create: NearbyBloc.new,
      started: const NearbyStarted(),
      
      child: const NearbyScreen(),
    );
  }
}