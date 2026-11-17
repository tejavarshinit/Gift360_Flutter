import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/register/register_bloc.dart';
import 'package:gift360/bloc/register/register_event.dart';
import 'package:gift360/bloc/register/register_state.dart';
import 'package:gift360/features/auth/presentation/screens/register_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<RegisterBloc, RegisterEvent, RegisterState>(
      create: RegisterBloc.new,
      started: const RegisterStarted(),
      maxContentWidth: 560,
      child: const RegisterScreen(),
    );
  }
}