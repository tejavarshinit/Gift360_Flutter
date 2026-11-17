import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shell-tab back: Cart / Brands / Categories → Home.
/// Native Pixel swipe-back blocking is owned by [SystemBackExitGuard]
/// (do not call setBlockSystemExit here — it was clearing the block on /nearby).
class MainTabBackGuard extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final Widget child;

  const MainTabBackGuard({
    super.key,
    required this.navigationShell,
    required this.child,
  });

  static const _tabPaths = {'/', '/categories', '/brands', '/cart'};

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final onMainTab = _tabPaths.contains(path);
    final onHome = index == 0 || path == '/';
    final blockTabExit = onMainTab && !onHome;

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!onMainTab) return false;
        if (!onHome) {
          navigationShell.goBranch(0, initialLocation: true);
          GoRouter.of(context).go('/');
          return true;
        }
        return false;
      },
      child: PopScope(
        canPop: !blockTabExit,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (blockTabExit) {
            navigationShell.goBranch(0, initialLocation: true);
            GoRouter.of(context).go('/');
          }
        },
        child: child,
      ),
    );
  }
}
