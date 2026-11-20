import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/navigation/app_back.dart';
import 'package:gift360/core/navigation/app_back_navigation_scope.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/core/widgets/app_bottom_nav.dart';
import 'package:gift360/core/widgets/gift_header.dart';
import 'package:gift360/core/widgets/notification_toast.dart';
import 'package:gift360/core/widgets/react_backdrop.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';
import 'package:gift360/presentation/responsive/app_breakpoints.dart';

class ScaffoldWithNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNav({super.key, required this.navigationShell});

  void _onShellBack(BuildContext context, {required bool hideChrome}) {
    if (hideChrome) {
      final controller = AppBackNavigationScope.maybeControllerOf(context);
      if (controller?.handleBack() == true) return;
      resetShellChrome();
      return;
    }
    performAppBack(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = AppBreakpoints.isDesktop(context);
    final isHome = navigationShell.currentIndex == 0;

    return ValueListenableBuilder<int>(
      valueListenable: shellChromeHideCount,
      builder: (context, hideCount, _) {
        final hideChrome = hideCount > 0;
        final isCart = navigationShell.currentIndex == 3;
        // Cart has its own hero header — hide Gift360 chrome there.
        final showGiftHeader = !isHome && !hideChrome && !isCart;
        final body = Stack(
          children: [
            Column(
              children: [
                if (showGiftHeader) const GiftHeader(),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: showGiftHeader,
                    child: ReactBackdrop(child: navigationShell),
                  ),
                ),
              ],
            ),
            const NotificationToast(),
          ],
        );

        if (!wide) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _onShellBack(context, hideChrome: hideChrome);
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: body,
              bottomNavigationBar: hideChrome
                  ? null
                  : AppBottomNav(
                      currentIndex: navigationShell.currentIndex,
                    ),
            ),
          );
        }

        final cartCount = ref.watch(cartItemCountProvider);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _onShellBack(context, hideChrome: hideChrome);
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Row(
              children: [
                if (!hideChrome)
                  NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: navigationShell.goBranch,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppColors.cardWhite,
                    indicatorColor:
                        AppColors.primaryPurple.withValues(alpha: 0.12),
                    selectedIconTheme:
                        const IconThemeData(color: AppColors.navActive),
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
                        selectedIcon:
                            _RailCartIcon(count: cartCount, selected: true),
                        label: const Text('Cart'),
                      ),
                    ],
                  ),
                if (!hideChrome) const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
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
