import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_login/reseller_login_bloc.dart';
import 'package:gift360/bloc/reseller_login/reseller_login_event.dart';
import 'package:gift360/bloc/reseller_login/reseller_login_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_login_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerLoginView extends StatelessWidget {
  const ResellerLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResellerLoginBloc, ResellerLoginEvent, ResellerLoginState>(
      create: ResellerLoginBloc.new,
      started: const ResellerLoginStarted(),
      maxContentWidth: 560,
      child: const ResellerLoginScreen(),
    );
  }
}