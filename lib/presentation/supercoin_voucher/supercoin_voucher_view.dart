import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/supercoin_voucher/supercoin_voucher_bloc.dart';
import 'package:gift360/bloc/supercoin_voucher/supercoin_voucher_event.dart';
import 'package:gift360/bloc/supercoin_voucher/supercoin_voucher_state.dart';
import 'package:gift360/features/supercoin/presentation/screens/supercoin_voucher_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class SupercoinVoucherView extends StatelessWidget {
  const SupercoinVoucherView({super.key});

  @override
  Widget build(BuildContext context) {
    // Full-bleed transparent host — no tablet frame so home stays visible.
    return ConnectedPage<SupercoinVoucherBloc, SupercoinVoucherEvent,
        SupercoinVoucherState>(
      create: SupercoinVoucherBloc.new,
      started: const SupercoinVoucherStarted(),
      child: const SuperCoinVoucherScreen(),
    );
  }
}