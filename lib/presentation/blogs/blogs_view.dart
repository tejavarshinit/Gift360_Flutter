import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/blogs/blogs_bloc.dart';
import 'package:gift360/bloc/blogs/blogs_event.dart';
import 'package:gift360/bloc/blogs/blogs_state.dart';
import 'package:gift360/features/blogs/presentation/screens/blog_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BlogsView extends StatelessWidget {
  const BlogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BlogsBloc, BlogsEvent, BlogsState>(
      create: BlogsBloc.new,
      started: const BlogsStarted(),
      maxContentWidth: 960,
      child: const BlogScreen(),
    );
  }
}