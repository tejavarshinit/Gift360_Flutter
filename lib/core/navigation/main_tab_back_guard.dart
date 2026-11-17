import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Intercepts Android system back (including Pixel swipe-back) on shell tabs
/// and navigates to Home instead of finishing the Activity.
class MainTabBackGuard extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final Widget child;

  const MainTabBackGuard({
    super.key,
    required this.navigationShell,
    required this.child,
  });

  @override
  State<MainTabBackGuard> createState() => _MainTabBackGuardState();
}

class _MainTabBackGuardState extends State<MainTabBackGuard> {
  static const _tabPaths = {'/', '/categories', '/brands', '/cart'};
  static const _navChannel = MethodChannel('com.gift360.gift360/navigation');

  bool _blockExit = false;

  bool get _onHome {
    final path = GoRouterState.of(context).uri.path;
    return widget.navigationShell.currentIndex == 0 || path == '/';
  }

  bool get _onMainTab {
    final path = GoRouterState.of(context).uri.path;
    return _tabPaths.contains(path);
  }

  bool get _shouldBlockExit => _onMainTab && !_onHome;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNativeBackBlock();
  }

  @override
  void didUpdateWidget(covariant MainTabBackGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNativeBackBlock();
  }

  Future<void> _syncNativeBackBlock() async {
    final block = _shouldBlockExit;
    if (block == _blockExit) {
      // Still refresh framework flag — route may have changed.
    }
    _blockExit = block;

    // Tell Flutter engine / Android whether we handle back (blocks Activity finish).
    SystemNavigator.setFrameworkHandlesBack(block);

    try {
      await _navChannel.invokeMethod<void>('setBlockSystemExit', block);
    } catch (_) {
      // Channel missing on web / older installs — PopScope still applies.
    }
  }

  void _goHome() {
    widget.navigationShell.goBranch(0, initialLocation: true);
    GoRouter.of(context).go('/');
    _syncNativeBackBlock();
  }

  @override
  void dispose() {
    SystemNavigator.setFrameworkHandlesBack(false);
    try {
      _navChannel.invokeMethod<void>('setBlockSystemExit', false);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild + re-sync whenever shell index or location changes.
    final index = widget.navigationShell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final blockExit = _tabPaths.contains(path) && index != 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (blockExit != _blockExit) {
        _syncNativeBackBlock();
      }
    });

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!_onMainTab) return false;
        if (!_onHome) {
          _goHome();
          return true;
        }
        return false;
      },
      child: PopScope(
        canPop: !blockExit,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (blockExit) _goHome();
        },
        child: widget.child,
      ),
    );
  }
}
