import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/forgot_password/forgot_password_bloc.dart';
import 'package:gift360/bloc/forgot_password/forgot_password_event.dart';
import 'package:gift360/bloc/forgot_password/forgot_password_state.dart';
import 'package:gift360/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ForgotPasswordBloc, ForgotPasswordEvent, ForgotPasswordState>(
      create: ForgotPasswordBloc.new,
      started: const ForgotPasswordStarted(),
      maxContentWidth: 560,
      child: const ForgotPasswordScreen(),
    );
  }
}