import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/blog_detail/blog_detail_bloc.dart';
import 'package:gift360/bloc/blog_detail/blog_detail_event.dart';
import 'package:gift360/bloc/blog_detail/blog_detail_state.dart';
import 'package:gift360/features/blog/presentation/screens/single_blog_page.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class BlogDetailView extends StatelessWidget {
  const BlogDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<BlogDetailBloc, BlogDetailEvent, BlogDetailState>(
      create: BlogDetailBloc.new,
      started: const BlogDetailStarted(),
      maxContentWidth: 840,
      child: SingleBlogPage(id: id),
    );
  }
}