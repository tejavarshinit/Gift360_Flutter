import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/faq_topic/faq_topic_bloc.dart';
import 'package:gift360/bloc/faq_topic/faq_topic_event.dart';
import 'package:gift360/bloc/faq_topic/faq_topic_state.dart';
import 'package:gift360/features/faq/presentation/screens/faq_topic_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class FaqTopicView extends StatelessWidget {
  const FaqTopicView({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<FaqTopicBloc, FaqTopicEvent, FaqTopicState>(
      create: FaqTopicBloc.new,
      started: const FaqTopicStarted(),
      maxContentWidth: 840,
      child: FaqTopicScreen(topicId: topicId),
    );
  }
}