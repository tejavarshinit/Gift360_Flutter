import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/delete_account/delete_account_bloc.dart';
import 'package:gift360/bloc/delete_account/delete_account_event.dart';
import 'package:gift360/bloc/delete_account/delete_account_state.dart';
import 'package:gift360/features/legal/presentation/screens/delete_account_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class DeleteAccountView extends StatelessWidget {
  const DeleteAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<DeleteAccountBloc, DeleteAccountEvent, DeleteAccountState>(
      create: DeleteAccountBloc.new,
      started: const DeleteAccountStarted(),
      maxContentWidth: 720,
      child: const DeleteAccountScreen(),
    );
  }
}