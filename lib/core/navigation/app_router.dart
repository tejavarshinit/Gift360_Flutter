import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/screens/login_screen.dart';
import 'package:gift360/features/auth/presentation/screens/register_screen.dart';
import 'package:gift360/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:gift360/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:gift360/features/home/presentation/screens/home_screen.dart';
import 'package:gift360/features/brands/presentation/screens/brands_screen.dart';
import 'package:gift360/features/categories/presentation/screens/categories_screen.dart';
import 'package:gift360/features/cart/presentation/screens/cart_screen.dart';
import 'package:gift360/features/orders/presentation/screens/orders_screen.dart';
import 'package:gift360/features/profile/presentation/screens/profile_screen.dart';
import 'package:gift360/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:gift360/features/landing/presentation/screens/distributor_screen.dart';
import 'package:gift360/features/landing/presentation/screens/reseller_screen.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_login_screen.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_dashboard_screen.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_catalog_screen.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_cart_screen.dart';
import 'package:gift360/features/reseller/presentation/screens/reseller_reset_password_screen.dart';
import 'package:gift360/features/landing/presentation/screens/corporate_screen.dart';
import 'package:gift360/features/legal/presentation/screens/privacy_screen.dart';
import 'package:gift360/features/legal/presentation/screens/terms_screen.dart';
import 'package:gift360/features/legal/presentation/screens/refund_screen.dart';
import 'package:gift360/features/legal/presentation/screens/delete_account_screen.dart';
import 'package:gift360/features/faq/presentation/screens/faq_screen.dart';
import 'package:gift360/features/blogs/presentation/screens/blog_screen.dart';
import 'package:gift360/features/blog/presentation/screens/single_blog_page.dart';
import 'package:gift360/features/nearby/presentation/screens/nearby_screen.dart';
import 'package:gift360/features/brands/presentation/screens/brand_details_screen.dart';
import 'package:gift360/features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import 'package:gift360/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:gift360/features/offers/presentation/screens/offers_screen.dart';
import 'package:gift360/features/faq/presentation/screens/faq_topic_screen.dart';
import 'package:gift360/features/legal/presentation/screens/login_issues_screen.dart';
import 'package:gift360/features/supercoin/presentation/screens/supercoin_voucher_screen.dart';
import 'package:gift360/features/bulk_purchase/presentation/screens/bulk_purchase_screen.dart';
import 'package:gift360/features/payment/presentation/screens/payment_webview_screen.dart';
import 'package:gift360/features/payment/presentation/screens/payment_result_screen.dart';
import 'package:gift360/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:gift360/features/orders/presentation/screens/my_orders_screen.dart';
import 'package:gift360/features/order/presentation/screens/order_checkout_screen.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'app_back_navigation_scope.dart';
import 'location_tracker.dart';
import 'scaffold_with_nav.dart';

/// Tracks onboarding completion, persisted in SharedPreferences under
/// `g360_onboarding_v3` (matches React's `localStorage["g360_onboarding_v3"]`).
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(bool initial) : super(initial);

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
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    observers: [LocationObserver()],
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider) != null;
      final authInitialized = ref.read(authInitializedProvider);
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

      // Wait until the previous session has been cleared before routing.
      if (!authInitialized) {
        return null;
      }

      if (!isLoggedIn && !isPublicPath) {
        return '/login';
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
        builder: (context, state) => const OnboardingPage(),
      ),
      _backAwareRoute(
        path: '/login',
        builder: (context, state) {
          final isSessionExpired =
              state.uri.queryParameters['session'] == 'expired';
          return LoginScreen(isSessionExpired: isSessionExpired);
        },
      ),
      _backAwareRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      _backAwareRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      _backAwareRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      _backAwareRoute(
        path: '/brand/:id',
        builder: (context, state) =>
            BrandDetailsScreen(brandId: state.pathParameters['id']!),
      ),
      _backAwareRoute(
        path: '/payment-webview',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return PaymentWebViewScreen(
            paymentUrl: extras['paymentUrl'] as String? ?? '',
            orderNumber: extras['orderNumber'] as String?,
          );
        },
      ),
      _backAwareRoute(
        path: '/payment-result',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return PaymentResultScreen(
            status: params['status'],
            txnId: params['txnid'] ?? params['txnId'],
            error: params['error'],
            orderNumber: params['orderNumber'],
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppBackNavigationScope(
            router: GoRouter.of(context),
            child: ScaffoldWithNav(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesScreen(),
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
                  return BrandsScreen(
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
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
        ],
      ),
      _backAwareRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      _backAwareRoute(
        path: '/my-orders',
        builder: (context, state) => const MyOrdersScreen(),
      ),
      _backAwareRoute(
        path: '/my-orders/:orderNumber/checkout',
        builder: (context, state) => OrderCheckoutScreen(
          orderNumber: state.pathParameters['orderNumber']!,
        ),
      ),
      _backAwareRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      _backAwareRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      _backAwareRoute(
        path: '/distributor',
        builder: (context, state) => const DistributorScreen(),
      ),
      _backAwareRoute(
        path: '/reseller',
        builder: (context, state) => const ResellerScreen(),
      ),
      _backAwareRoute(
        path: '/reseller/login',
        builder: (context, state) => const ResellerLoginScreen(),
      ),
      _backAwareRoute(
        path: '/reseller/dashboard',
        builder: (context, state) => const ResellerDashboardScreen(),
      ),
      _backAwareRoute(
        path: '/reseller/catalog',
        builder: (context, state) => const ResellerCatalogScreen(),
      ),
      _backAwareRoute(
        path: '/reseller/cart',
        builder: (context, state) => const ResellerCartScreen(),
      ),
      _backAwareRoute(
        path: '/reseller/reset-password',
        builder: (context, state) => ResellerResetPasswordScreen(
          token: state.uri.queryParameters['token'],
        ),
      ),
      _backAwareRoute(
        path: '/changepassword',
        builder: (context, state) => ResellerResetPasswordScreen(
          token: state.uri.queryParameters['token'],
        ),
      ),
      _backAwareRoute(
        path: '/corporate',
        builder: (context, state) => const CorporateScreen(),
      ),
      _backAwareRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      _backAwareRoute(
        path: '/terms',
        builder: (context, state) => const TermsScreen(),
      ),
      _backAwareRoute(
        path: '/refund',
        builder: (context, state) => const RefundScreen(),
      ),
      _backAwareRoute(
        path: '/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      _backAwareRoute(
        path: '/offers',
        builder: (context, state) => const OffersScreen(),
      ),
      _backAwareRoute(
        path: '/login-issues',
        builder: (context, state) => const LoginIssuesScreen(),
      ),
      _backAwareRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      _backAwareRoute(
        path: '/faq/:id',
        builder: (context, state) =>
            FaqTopicScreen(topicId: state.pathParameters['id'] ?? ''),
      ),
      _backAwareRoute(
        path: '/blogs',
        builder: (context, state) => const BlogScreen(),
      ),
      _backAwareRoute(
        path: '/blogs/:id',
        builder: (context, state) => SingleBlogPage(
          id: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0,
        ),
      ),
      _backAwareRoute(
        path: '/spin-wheel',
        builder: (context, state) => const SpinWheelScreen(),
      ),
      _backAwareRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsScreen(),
      ),
      _backAwareRoute(
        path: '/supercoin-voucher',
        builder: (context, state) => const SuperCoinVoucherScreen(),
      ),
      _backAwareRoute(
        path: '/bulk-purchase',
        builder: (context, state) => const BulkPurchaseScreen(),
      ),
      _backAwareRoute(
        path: '/nearby',
        builder: (context, state) => const NearbyScreen(),
      ),
    ],
  );
});
