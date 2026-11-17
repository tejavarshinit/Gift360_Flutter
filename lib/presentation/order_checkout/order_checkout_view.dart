import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/order_checkout/order_checkout_bloc.dart';
import 'package:gift360/bloc/order_checkout/order_checkout_event.dart';
import 'package:gift360/bloc/order_checkout/order_checkout_state.dart';
import 'package:gift360/features/order/presentation/screens/order_checkout_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class OrderCheckoutView extends StatelessWidget {
  const OrderCheckoutView({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<OrderCheckoutBloc, OrderCheckoutEvent, OrderCheckoutState>(
      create: OrderCheckoutBloc.new,
      started: const OrderCheckoutStarted(),
      maxContentWidth: 960,
      child: OrderCheckoutScreen(orderNumber: orderNumber),
    );
  }
}