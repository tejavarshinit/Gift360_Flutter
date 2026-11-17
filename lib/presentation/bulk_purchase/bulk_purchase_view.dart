import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/bulk_purchase/bulk_purchase_bloc.dart';
import 'package:gift360/bloc/bulk_purchase/bulk_purchase_event.dart';
import 'package:gift360/bloc/bulk_purchase/bulk_purchase_state.dart';
import 'package:gift360/features/bulk_purchase/presentation/screens/bulk_purchase_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BulkPurchaseView extends StatelessWidget {
  const BulkPurchaseView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BulkPurchaseBloc, BulkPurchaseEvent, BulkPurchaseState>(
      create: BulkPurchaseBloc.new,
      started: const BulkPurchaseStarted(),
      maxContentWidth: 960,
      child: const BulkPurchaseScreen(),
    );
  }
}