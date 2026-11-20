import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/app_navigator.dart';

/// Unified back: pop stack → previous tab (Home) → stay put.
///
/// Returns `true` when the back event was consumed (app must not exit).
/// Returns `false` when a full-bleed overlay is open so a child
/// [BackButtonListener] / registered handler can close it first.
bool performAppBack(BuildContext context) {
  // Overlays (Payment Details) own back via their own listeners / scope handlers.
  if (shellChromeHideCount.value > 0) {
    return false;
  }

  final router = GoRouter.of(context);

  // Real navigation stack (Home → Brands?categories=, Profile → Orders, etc.).
  if (router.canPop()) {
    router.pop();
    return true;
  }

  // Shell tabs: Categories / Brands / Cart → Home.
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null && shell.currentIndex != 0) {
    shell.goBranch(0, initialLocation: true);
    return true;
  }

  // Outside the tab shell (Reseller / Distributor / Corporate / Profile, etc.)
  // with an empty stack — return Home instead of throwing on pop.
  final path = router.routerDelegate.currentConfiguration.uri.path;
  if (path != '/') {
    router.go('/');
    return true;
  }

  // Already on Home — consume back, do not close the app.
  return true;
}
