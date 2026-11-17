import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/my_orders/my_orders_bloc.dart';
import 'package:gift360/bloc/my_orders/my_orders_event.dart';
import 'package:gift360/bloc/my_orders/my_orders_state.dart';
import 'package:gift360/features/orders/presentation/screens/my_orders_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class MyOrdersView extends StatelessWidget {
  const MyOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<MyOrdersBloc, MyOrdersEvent, MyOrdersState>(
      create: MyOrdersBloc.new,
      started: const MyOrdersStarted(),
      maxContentWidth: 1120,
      child: const MyOrdersScreen(),
    );
  }
}