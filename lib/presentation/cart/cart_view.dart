import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/cart/cart_bloc.dart';
import 'package:gift360/bloc/cart/cart_event.dart';
import 'package:gift360/bloc/cart/cart_state.dart';
import 'package:gift360/features/cart/presentation/screens/cart_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<CartBloc, CartEvent, CartState>(
      create: CartBloc.new,
      started: const CartStarted(),
      maxContentWidth: 960,
      child: const CartScreen(),
    );
  }
}