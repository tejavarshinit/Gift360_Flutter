import 'package:flutter/widgets.dart';

import 'package:gift360/bloc/reseller_catalog/reseller_catalog_bloc.dart';
import 'package:gift360/bloc/reseller_catalog/reseller_catalog_event.dart';
import 'package:gift360/bloc/reseller_catalog/reseller_catalog_state.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_catalog_screen.dart';
import 'package:gift360/presentation/responsive/connected_page.dart';

class ResellerCatalogView extends StatelessWidget {
  const ResellerCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectedPage<ResellerCatalogBloc, ResellerCatalogEvent, ResellerCatalogState>(
      create: ResellerCatalogBloc.new,
      started: const ResellerCatalogStarted(),
      maxContentWidth: 1120,
      child: const ResellerCatalogScreen(),
    );
  }
}