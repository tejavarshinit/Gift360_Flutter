import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reset_password/reset_password_bloc.dart';
import 'package:gift360/bloc/reset_password/reset_password_event.dart';
import 'package:gift360/bloc/reset_password/reset_password_state.dart';
import 'package:gift360/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResetPasswordView extends StatelessWidget {
  const ResetPasswordView({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResetPasswordBloc, ResetPasswordEvent, ResetPasswordState>(
      create: ResetPasswordBloc.new,
      started: const ResetPasswordStarted(),
      maxContentWidth: 560,
      child: ResetPasswordScreen(token: token),
    );
  }
}