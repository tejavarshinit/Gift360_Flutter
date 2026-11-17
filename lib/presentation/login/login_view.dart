import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/login/login_bloc.dart';
import 'package:gift360/bloc/login/login_event.dart';
import 'package:gift360/bloc/login/login_state.dart';
import 'package:gift360/features/auth/presentation/screens/login_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key, this.isSessionExpired = false});

  final bool isSessionExpired;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<LoginBloc, LoginEvent, LoginState>(
      create: LoginBloc.new,
      started: const LoginStarted(),
      maxContentWidth: 560,
      child: LoginScreen(isSessionExpired: isSessionExpired),
    );
  }
}