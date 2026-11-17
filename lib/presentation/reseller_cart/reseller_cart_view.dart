import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_cart/reseller_cart_bloc.dart';
import 'package:gift360/bloc/reseller_cart/reseller_cart_event.dart';
import 'package:gift360/bloc/reseller_cart/reseller_cart_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_cart_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerCartView extends StatelessWidget {
  const ResellerCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResellerCartBloc, ResellerCartEvent, ResellerCartState>(
      create: ResellerCartBloc.new,
      started: const ResellerCartStarted(),
      maxContentWidth: 960,
      child: const ResellerCartScreen(),
    );
  }
}