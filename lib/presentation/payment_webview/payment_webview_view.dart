import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/payment_webview/payment_webview_bloc.dart';
import 'package:gift360/bloc/payment_webview/payment_webview_event.dart';
import 'package:gift360/bloc/payment_webview/payment_webview_state.dart';
import 'package:gift360/features/payment/presentation/screens/payment_webview_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class PaymentWebviewView extends StatelessWidget {
  const PaymentWebviewView({
    super.key,
    required this.paymentUrl,
    this.orderNumber,
  });

  final String paymentUrl;
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<PaymentWebviewBloc, PaymentWebviewEvent, PaymentWebviewState>(
      create: PaymentWebviewBloc.new,
      started: const PaymentWebviewStarted(),
      child: PaymentWebViewScreen(
        paymentUrl: paymentUrl,
        orderNumber: orderNumber,
      ),
    );
  }
}