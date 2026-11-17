import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/widgets/app_bottom_nav.dart';
import 'package:gift360/core/widgets/gift_header.dart';
import 'package:gift360/core/widgets/notification_toast.dart';
import 'package:gift360/core/widgets/react_backdrop.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/presentation/responsive/app_breakpoints.dart';

class ScaffoldWithNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNav({super.key, required this.navigationShell});

  void _handleTabBack() {
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(
        0,
        initialLocation: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = AppBreakpoints.isDesktop(context);
    final isHome = navigationShell.currentIndex == 0;
    final body = Stack(
      children: [
        Column(
          children: [
            if (!isHome) const GiftHeader(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !isHome,
                child: ReactBackdrop(child: navigationShell),
              ),
            ),
          ],
        ),
        const NotificationToast(),
      ],
    );

    if (!wide) {
      // Wrap the whole scaffold so Android/iOS back never exits from tabs.
      return PopScope(
        canPop: isHome,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleTabBack();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: body,
          bottomNavigationBar: AppBottomNav(
            currentIndex: navigationShell.currentIndex,
          ),
        ),
      );
    }

    final cartCount = ref.watch(cartItemCountProvider);
    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleTabBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.cardWhite,
              indicatorColor: AppColors.primaryPurple.withValues(alpha: 0.12),
              selectedIconTheme: const IconThemeData(color: AppColors.navActive),
              unselectedIconTheme:
                  const IconThemeData(color: AppColors.navInactive),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.navActive,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.navInactive,
                fontSize: 12,
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: Text('Categories'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.store_outlined),
                  selectedIcon: Icon(Icons.store),
                  label: Text('Brands'),
                ),
                NavigationRailDestination(
                  icon: _RailCartIcon(count: cartCount),
                  selectedIcon: _RailCartIcon(count: cartCount, selected: true),
                  label: const Text('Cart'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _RailCartIcon extends StatelessWidget {
  const _RailCartIcon({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.navActive,
      child: Icon(selected ? Icons.shopping_cart : Icons.shopping_cart_outlined),
    );
  }
}
