import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/navigation/app_back_navigation_scope.dart';
import 'package:gift360/features/brands/presentation/widgets/brand_voucher_modal.dart';

void main() {
  testWidgets('system back pops nested routes in order', (tester) async {
    final router = _testRouter();
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.push('/details');
    await tester.pumpAndSettle();
    router.push('/details/inner');
    await tester.pumpAndSettle();

    expect(find.text('Inner details'), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('system back from a standalone deep link returns home', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/standalone');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(router.canPop(), isFalse);
    expect(find.text('Standalone'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('system back from a tab root returns to the home tab', (
    tester,
  ) async {
    final router = _tabRouter();
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.go('/categories');
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
    'system back dismisses an overlay then returns to previous route',
    (tester) async {
      var overlayClosed = false;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) =>
                _screen(context, const Scaffold(body: Text('Home'))),
            routes: [
              GoRoute(
                path: 'payment',
                builder: (context, _) => _screen(
                  context,
                  Scaffold(
                    body: _RegisterBackHandler(
                      onBack: () => overlayClosed = true,
                      child: const Text('Payment details'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      router.push('/payment');
      await tester.pumpAndSettle();
      expect(find.text('Payment details'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(overlayClosed, isTrue);
      expect(find.text('Payment details'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('system back dismisses the brand voucher sheet first', (
    tester,
  ) async {
    final router = _voucherRouter();
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    router.go('/brands');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open vouchers'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Test brand'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 350));

    expect(router.routerDelegate.currentConfiguration.uri.path, '/brands');
    expect(find.text('Test brand'), findsNothing);
    expect(find.text('Brands context'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}

GoRouter _testRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) =>
            _screen(context, const Scaffold(body: Text('Home'))),
        routes: [
          GoRoute(
            path: 'details',
            builder: (context, _) =>
                _screen(context, const Scaffold(body: Text('Details'))),
            routes: [
              GoRoute(
                path: 'inner',
                builder: (context, _) => _screen(
                  context,
                  const Scaffold(body: Text('Inner details')),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/standalone',
        builder: (context, _) =>
            _screen(context, const Scaffold(body: Text('Standalone'))),
      ),
    ],
  );
}

GoRouter _tabRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, _, navigationShell) => AppBackNavigationScope(
          router: GoRouter.of(context),
          child: Scaffold(body: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Home')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (_, _) => const Scaffold(body: Text('Categories')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

GoRouter _voucherRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, _, navigationShell) => AppBackNavigationScope(
          router: GoRouter.of(context),
          child: Scaffold(body: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Home')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brands',
                builder: (_, _) => const Scaffold(body: _VoucherHost()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _app(GoRouter router) {
  return MaterialApp.router(routerConfig: router);
}

Widget _screen(BuildContext context, Widget child) {
  return AppBackNavigationScope(router: GoRouter.of(context), child: child);
}

class _RegisterBackHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onBack;

  const _RegisterBackHandler({required this.child, required this.onBack});

  @override
  State<_RegisterBackHandler> createState() => _RegisterBackHandlerState();
}

class _RegisterBackHandlerState extends State<_RegisterBackHandler> {
  AppBackNavigationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppBackNavigationScope.maybeControllerOf(context);
    _controller?.register(this, () {
      widget.onBack();
      _controller?.unregister(this);
    }, isActive: () => true);
  }

  @override
  void dispose() {
    _controller?.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _VoucherHost extends StatefulWidget {
  const _VoucherHost();

  @override
  State<_VoucherHost> createState() => _VoucherHostState();
}

class _VoucherHostState extends State<_VoucherHost> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Center(child: Text('Brands context')),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _isOpen = true),
            child: const Text('Open vouchers'),
          ),
        ),
        BrandVoucherModal(
          isOpen: _isOpen,
          brandName: 'Test brand',
          loading: true,
          onClose: () => setState(() => _isOpen = false),
        ),
      ],
    );
  }
}
