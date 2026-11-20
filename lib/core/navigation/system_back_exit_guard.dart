import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/app_router.dart';

/// Single owner of Android `setBlockSystemExit` / predictive swipe-back.
/// Blocks Activity finish on every in-app route so back always returns to the
/// previous page (or Home) instead of closing Gift360.
class SystemBackExitGuard extends ConsumerStatefulWidget {
  final Widget child;

  const SystemBackExitGuard({super.key, required this.child});

  @override
  ConsumerState<SystemBackExitGuard> createState() =>
      _SystemBackExitGuardState();
}

class _SystemBackExitGuardState extends ConsumerState<SystemBackExitGuard> {
  static const _navChannel = MethodChannel('com.gift360.gift360/navigation');

  /// Only leave the process from auth entry screens (user explicitly backs out
  /// of login / onboarding). Everywhere else must stay in-app.
  static const _exitAllowed = {
    '/login',
    '/register',
    '/onboarding',
    '/forgot-password',
    '/reset-password',
  };

  bool _blockExit = false;
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = ref.read(goRouterProvider);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteChanged);
    }
    _sync();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _apply(false);
    super.dispose();
  }

  void _onRouteChanged() {
    if (mounted) _sync();
  }

  void _sync() {
    final path =
        _router?.routerDelegate.currentConfiguration.uri.path ?? '/';
    final block = !_exitAllowed.contains(path);
    if (block == _blockExit) {
      _apply(block);
      return;
    }
    _blockExit = block;
    _apply(block);
  }

  Future<void> _apply(bool block) async {
    SystemNavigator.setFrameworkHandlesBack(block);
    try {
      await _navChannel.invokeMethod<void>('setBlockSystemExit', block);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
