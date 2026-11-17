import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/payment/payment_bloc.dart';
import 'package:gift360/bloc/payment/payment_event.dart';
import 'package:gift360/bloc/payment/payment_state.dart';
import 'package:gift360/features/payment/presentation/screens/payment_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class PaymentView extends StatelessWidget {
  const PaymentView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<PaymentBloc, PaymentEvent, PaymentState>(
      create: PaymentBloc.new,
      started: const PaymentStarted(),
      maxContentWidth: 720,
      child: const PaymentScreen(),
    );
  }
}