import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/orders/orders_bloc.dart';
import 'package:gift360/bloc/orders/orders_event.dart';
import 'package:gift360/bloc/orders/orders_state.dart';
import 'package:gift360/features/orders/presentation/screens/orders_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<OrdersBloc, OrdersEvent, OrdersState>(
      create: OrdersBloc.new,
      started: const OrdersStarted(),
      maxContentWidth: 1120,
      child: const OrdersScreen(),
    );
  }
}