import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/categories/categories_bloc.dart';
import 'package:gift360/bloc/categories/categories_event.dart';
import 'package:gift360/bloc/categories/categories_state.dart';
import 'package:gift360/features/categories/presentation/screens/categories_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<CategoriesBloc, CategoriesEvent, CategoriesState>(
      create: CategoriesBloc.new,
      started: const CategoriesStarted(),
      maxContentWidth: 1120,
      child: const CategoriesScreen(),
    );
  }
}