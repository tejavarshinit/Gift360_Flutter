import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/presentation/presentation.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'app_back_navigation_scope.dart';
import 'location_tracker.dart';
import 'main_tab_back_guard.dart';
import 'scaffold_with_nav.dart';

/// Tracks onboarding completion, persisted in SharedPreferences under
/// `g360_onboarding_v3` (matches React's `localStorage["g360_onboarding_v3"]`).
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(super.initial);

  /// Mark onboarding complete — persists to SharedPreferences and updates state.
  Future<void> complete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('g360_onboarding_v3', true);
    } catch (_) {}
    state = true;
  }
}

final onboardingCompleteProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
      return OnboardingNotifier(false);
    });

GoRoute _backAwareRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) => AppBackNavigationScope(
      router: GoRouter.of(context),
      child: builder(context, state),
    ),
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Re-run redirects when session restore / login / logout changes auth.
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthUser?>(authProvider, (_, _) => refresh.value++);
  ref.listen<bool>(authInitializedProvider, (_, _) => refresh.value++);
  ref.listen<bool>(postLoginSetupHoldingProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    refreshListenable: refresh,
    observers: [LocationObserver()],
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider) != null;
      final authInitialized = ref.read(authInitializedProvider);
      final holdingLoginForSetup = ref.read(postLoginSetupHoldingProvider);
      final path = state.matchedLocation;

      final isPublicPath =
          path == '/onboarding' ||
          path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/reset-password' ||
          path == '/payment-result' ||
          path.startsWith('/payment-webview') ||
          // Reseller area uses its own single-session auth (not consumer auth).
          path == '/reseller' ||
          path.startsWith('/reseller/') ||
          path == '/changepassword';

      // Wait until secure-storage session restore finishes.
      if (!authInitialized) {
        return null;
      }

      if (!isLoggedIn && !isPublicPath) {
        return '/login';
      }
      // Keep user on login while biometric / MPIN setup dialogs run.
      if (isLoggedIn && holdingLoginForSetup && path == '/login') {
        return null;
      }
      if (isLoggedIn &&
          (path == '/login' || path == '/register' || path == '/onboarding')) {
        return '/';
      }
      return null;
    },
    routes: [
      _backAwareRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      _backAwareRoute(
        path: '/login',
        builder: (context, state) {
          final isSessionExpired =
              state.uri.queryParameters['session'] == 'expired';
          return LoginView(isSessionExpired: isSessionExpired);
        },
      ),
      _backAwareRoute(
        path: '/register',
        builder: (context, state) => const RegisterView(),
      ),
      _backAwareRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordView(),
      ),
      _backAwareRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordView(token: state.uri.queryParameters['token']),
      ),
      _backAwareRoute(
        path: '/brand/:id',
        builder: (context, state) =>
            BrandDetailsView(brandId: state.pathParameters['id']!),
      ),
      _backAwareRoute(
        path: '/payment-webview',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return PaymentWebviewView(
            paymentUrl: extras['paymentUrl'] as String? ?? '',
            orderNumber: extras['orderNumber'] as String?,
          );
        },
      ),
      _backAwareRoute(
        path: '/payment-result',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return PaymentResultView(
            status: params['status'],
            txnId: params['txnid'] ?? params['txnId'],
            error: params['error'],
            orderNumber: params['orderNumber'],
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainTabBackGuard(
            navigationShell: navigationShell,
            child: AppBackNavigationScope(
              router: GoRouter.of(context),
              child: ScaffoldWithNav(navigationShell: navigationShell),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomepageView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/brands',
                builder: (context, state) {
                  final search = state.uri.queryParameters['search'];
                  final categories = state.uri.queryParameters['categories'];
                  final supercoins =
                      state.uri.queryParameters['supercoins'] == '1';
                  final discounts =
                      state.uri.queryParametersAll['discount'] ??
                      const <String>[];
                  return BrandsView(
                    initialSearch: search,
                    initialCategory: categories,
                    initialSuperCoinsOnly: supercoins,
                    initialDiscountRanges: discounts,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartView(),
              ),
            ],
          ),
        ],
      ),
      _backAwareRoute(
        path: '/orders',
        builder: (context, state) => const OrdersView(),
      ),
      _backAwareRoute(
        path: '/my-orders',
        builder: (context, state) => const MyOrdersView(),
      ),
      _backAwareRoute(
        path: '/my-orders/:orderNumber/checkout',
        builder: (context, state) => OrderCheckoutView(
          orderNumber: state.pathParameters['orderNumber']!,
        ),
      ),
      _backAwareRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsView(),
      ),
      _backAwareRoute(
        path: '/profile',
        builder: (context, state) => const ProfileView(),
      ),
      _backAwareRoute(
        path: '/profile/details',
        builder: (context, state) => const ProfileDetailsView(),
      ),
      _backAwareRoute(
        path: '/distributor',
        builder: (context, state) => const DistributorView(),
      ),
      _backAwareRoute(
        path: '/reseller',
        builder: (context, state) => const ResellerView(),
      ),
      _backAwareRoute(
        path: '/reseller/login',
        builder: (context, state) => const ResellerLoginView(),
      ),
      _backAwareRoute(
        path: '/reseller/dashboard',
        builder: (context, state) => const ResellerDashboardView(),
      ),
      _backAwareRoute(
        path: '/reseller/catalog',
        builder: (context, state) => const ResellerCatalogView(),
      ),
      _backAwareRoute(
        path: '/reseller/cart',
        builder: (context, state) => const ResellerCartView(),
      ),
      _backAwareRoute(
        path: '/reseller/reset-password',
        builder: (context, state) => ResellerResetPasswordView(
          token: state.uri.queryParameters['token'],
        ),
      ),
      _backAwareRoute(
        path: '/changepassword',
        builder: (context, state) => ResellerResetPasswordView(
          token: state.uri.queryParameters['token'],
        ),
      ),
      _backAwareRoute(
        path: '/corporate',
        builder: (context, state) => const CorporateView(),
      ),
      _backAwareRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyView(),
      ),
      _backAwareRoute(
        path: '/terms',
        builder: (context, state) => const TermsView(),
      ),
      _backAwareRoute(
        path: '/refund',
        builder: (context, state) => const RefundView(),
      ),
      _backAwareRoute(
        path: '/delete-account',
        builder: (context, state) => const DeleteAccountView(),
      ),
      _backAwareRoute(
        path: '/offers',
        builder: (context, state) => const OffersView(),
      ),
      _backAwareRoute(
        path: '/login-issues',
        builder: (context, state) => const LoginIssuesView(),
      ),
      _backAwareRoute(
        path: '/faq',
        builder: (context, state) => const FaqView(),
      ),
      _backAwareRoute(
        path: '/faq/:id',
        builder: (context, state) =>
            FaqTopicView(topicId: state.pathParameters['id'] ?? ''),
      ),
      _backAwareRoute(
        path: '/blogs',
        builder: (context, state) => const BlogsView(),
      ),
      _backAwareRoute(
        path: '/blogs/:id',
        builder: (context, state) => BlogDetailView(
          id: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0,
        ),
      ),
      _backAwareRoute(
        path: '/spin-wheel',
        builder: (context, state) => const SpinWheelView(),
      ),
      _backAwareRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsView(),
      ),
      // Non-opaque page so the shell (home) stays painted underneath.
      GoRoute(
        path: '/supercoin-voucher',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: true,
            barrierColor: Colors.black54,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: AppBackNavigationScope(
              router: GoRouter.of(context),
              child: const SupercoinVoucherView(),
            ),
          );
        },
      ),
      _backAwareRoute(
        path: '/bulk-purchase',
        builder: (context, state) => const BulkPurchaseView(),
      ),
      _backAwareRoute(
        path: '/nearby',
        builder: (context, state) => const NearbyView(),
      ),
    ],
  );
});
