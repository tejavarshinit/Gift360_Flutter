import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/app_back.dart';

class AppBackNavigationScope extends StatefulWidget {
  final GoRouter router;
  final Widget child;

  const AppBackNavigationScope({
    super.key,
    required this.router,
    required this.child,
  });

  static AppBackNavigationController? maybeControllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BackNavigationControllerScope>()
        ?.controller;
  }

  @override
  State<AppBackNavigationScope> createState() => _AppBackNavigationScopeState();
}

class _AppBackNavigationScopeState extends State<AppBackNavigationScope> {
  final _controller = AppBackNavigationController();
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    // Rebuild when shell tab / route changes so PopScope canPop stays correct.
    widget.router.routerDelegate.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant AppBackNavigationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router.routerDelegate != widget.router.routerDelegate) {
      oldWidget.router.routerDelegate.removeListener(_refresh);
      widget.router.routerDelegate.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_refresh);
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Never allow the system to finish the Activity from this scope.
    // Native swipe block is owned by SystemBackExitGuard.
    return _BackNavigationControllerScope(
      controller: _controller,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_controller.handleBack()) return;
          performAppBack(context);
        },
        child: widget.child,
      ),
    );
  }
}

class AppBackNavigationController extends ChangeNotifier {
  final Map<Object, _BackHandler> _handlers = {};

  bool get hasActiveHandler =>
      _handlers.values.any((handler) => handler.isActive());

  void register(
    Object key,
    VoidCallback onBack, {
    required bool Function() isActive,
  }) {
    _handlers[key] = _BackHandler(onBack, isActive);
    notifyListeners();
  }

  void unregister(Object key) {
    if (_handlers.remove(key) != null) notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  bool handleBack() {
    for (final entry in _handlers.entries.toList().reversed) {
      if (entry.value.isActive()) {
        entry.value.onBack();
        return true;
      }
    }
    return false;
  }
}

class _BackHandler {
  final VoidCallback onBack;
  final bool Function() isActive;

  const _BackHandler(this.onBack, this.isActive);
}

class _BackNavigationControllerScope extends InheritedWidget {
  final AppBackNavigationController controller;

  const _BackNavigationControllerScope({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(_BackNavigationControllerScope oldWidget) =>
      controller != oldWidget.controller;
}
