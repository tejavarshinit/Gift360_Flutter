import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
  }

  @override
  void dispose() {
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
    final canPop = widget.router.canPop();
    final isHome =
        widget.router.routerDelegate.currentConfiguration.uri.path == '/';
    final hasBackHandler = _controller.hasActiveHandler;

    return _BackNavigationControllerScope(
      controller: _controller,
      child: PopScope(
        canPop: !hasBackHandler && (canPop || isHome),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_controller.handleBack()) return;
          if (!canPop && !isHome) widget.router.go('/');
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
