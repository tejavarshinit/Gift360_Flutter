import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/app_back.dart';
import 'package:gift360/core/navigation/app_navigator.dart';

/// Shell-tab back: always previous page / Home — never finish the Activity.
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
    return ValueListenableBuilder<int>(
      valueListenable: shellChromeHideCount,
      builder: (context, hideCount, _) {
        final path = GoRouterState.of(context).uri.path;
        final onMainTab = _tabPaths.contains(path);
        final overlayOpen = hideCount > 0;
        // Intercept main-tab backs so the app never exits from tabs/Home.
        final intercept = onMainTab && !overlayOpen;

        return BackButtonListener(
          onBackButtonPressed: () async {
            // Payment Details (etc.) must consume back first.
            if (overlayOpen) return false;
            if (!onMainTab) return false;
            return performAppBack(context);
          },
          child: PopScope(
            canPop: !intercept,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (overlayOpen) return;
              if (intercept) performAppBack(context);
            },
            child: child,
          ),
        );
      },
    );
  }
}
