import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/widgets/app_bottom_nav.dart';
import 'package:gift360/core/widgets/gift_header.dart';
import 'package:gift360/core/widgets/notification_toast.dart';
import 'package:gift360/core/widgets/react_backdrop.dart';

class ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const GiftHeader(),
              Expanded(
                child: ReactBackdrop(child: navigationShell),
              ),
            ],
          ),
          const NotificationToast(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: navigationShell.currentIndex),
    );
  }
}
