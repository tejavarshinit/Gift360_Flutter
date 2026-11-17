import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/login_issues/login_issues_bloc.dart';
import 'package:gift360/bloc/login_issues/login_issues_event.dart';
import 'package:gift360/bloc/login_issues/login_issues_state.dart';
import 'package:gift360/features/legal/presentation/screens/login_issues_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class LoginIssuesView extends StatelessWidget {
  const LoginIssuesView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<LoginIssuesBloc, LoginIssuesEvent, LoginIssuesState>(
      create: LoginIssuesBloc.new,
      started: const LoginIssuesStarted(),
      maxContentWidth: 840,
      child: const LoginIssuesScreen(),
    );
  }
}