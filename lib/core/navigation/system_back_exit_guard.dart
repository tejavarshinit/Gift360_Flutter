import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/app_router.dart';

/// Single owner of Android `setBlockSystemExit` / predictive swipe-back.
/// Blocks Activity finish on every route except Home + auth screens
/// (fixes Offers Near You / Cart / Brands Pixel gesture closing the app).
class SystemBackExitGuard extends ConsumerStatefulWidget {
  final Widget child;

  const SystemBackExitGuard({super.key, required this.child});

  @override
  ConsumerState<SystemBackExitGuard> createState() =>
      _SystemBackExitGuardState();
}

class _SystemBackExitGuardState extends ConsumerState<SystemBackExitGuard> {
  static const _navChannel = MethodChannel('com.gift360.gift360/navigation');
  static const _exitAllowed = {
    '/',
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
      // Re-assert native flag in case another caller cleared it.
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
