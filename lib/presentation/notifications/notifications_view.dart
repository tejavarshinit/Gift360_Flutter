import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/notifications/notifications_bloc.dart';
import 'package:gift360/bloc/notifications/notifications_event.dart';
import 'package:gift360/bloc/notifications/notifications_state.dart';
import 'package:gift360/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<NotificationsBloc, NotificationsEvent, NotificationsState>(
      create: NotificationsBloc.new,
      started: const NotificationsStarted(),
      maxContentWidth: 840,
      child: const NotificationsScreen(),
    );
  }
}