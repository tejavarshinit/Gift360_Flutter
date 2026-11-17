import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_reset_password/reseller_reset_password_bloc.dart';
import 'package:gift360/bloc/reseller_reset_password/reseller_reset_password_event.dart';
import 'package:gift360/bloc/reseller_reset_password/reseller_reset_password_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_reset_password_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerResetPasswordView extends StatelessWidget {
  const ResellerResetPasswordView({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<
      ResellerResetPasswordBloc,
      ResellerResetPasswordEvent,
      ResellerResetPasswordState
    >(
      create: ResellerResetPasswordBloc.new,
      started: const ResellerResetPasswordStarted(),
      maxContentWidth: 560,
      child: ResellerResetPasswordScreen(token: token),
    );
  }
}