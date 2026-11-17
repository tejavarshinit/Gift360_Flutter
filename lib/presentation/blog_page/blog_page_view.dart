import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/blog_page/blog_page_bloc.dart';
import 'package:gift360/bloc/blog_page/blog_page_event.dart';
import 'package:gift360/bloc/blog_page/blog_page_state.dart';
import 'package:gift360/features/blog/presentation/screens/blog_page.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BlogPageView extends StatelessWidget {
  const BlogPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BlogPageBloc, BlogPageEvent, BlogPageState>(
      create: BlogPageBloc.new,
      started: const BlogPageStarted(),
      maxContentWidth: 960,
      child: const BlogPage(),
    );
  }
}