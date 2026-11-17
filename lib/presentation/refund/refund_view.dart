import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/refund/refund_bloc.dart';
import 'package:gift360/bloc/refund/refund_event.dart';
import 'package:gift360/bloc/refund/refund_state.dart';
import 'package:gift360/features/legal/presentation/screens/refund_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class RefundView extends StatelessWidget {
  const RefundView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<RefundBloc, RefundEvent, RefundState>(
      create: RefundBloc.new,
      started: const RefundStarted(),
      maxContentWidth: 840,
      child: const RefundScreen(),
    );
  }
}