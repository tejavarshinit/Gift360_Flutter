import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:gift360/features/landing/presentation/screens/corporate_screen.dart';
import 'package:gift360/features/legal/presentation/screens/privacy_screen.dart';
import 'package:gift360/features/legal/presentation/screens/terms_screen.dart';
import 'package:gift360/features/legal/presentation/screens/refund_screen.dart';
import 'package:gift360/features/faq/presentation/screens/faq_screen.dart';
import 'package:gift360/features/blogs/presentation/screens/blog_screen.dart';
import 'package:gift360/features/blog/presentation/screens/single_blog_page.dart';
import 'package:gift360/features/nearby/presentation/screens/nearby_screen.dart';
import 'package:gift360/features/brands/presentation/screens/brand_details_screen.dart';
import 'package:gift360/features/spin_wheel/presentation/screens/spin_wheel_screen.dart';
import 'package:gift360/features/bulk_purchase/presentation/screens/bulk_purchase_screen.dart';
import 'package:gift360/features/payment/presentation/screens/payment_screen.dart';
import 'package:gift360/features/payment/presentation/screens/payment_webview_screen.dart';
import 'package:gift360/features/payment/presentation/screens/payment_result_screen.dart';
import 'package:gift360/features/notifications/presentation/screens/notifications_screen.dart';
import 'scaffold_with_nav.dart';

final onboardingCompleteProvider = Provider<bool>((ref) => false);

final goRouterProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref.read(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider) != null;
      final path = state.matchedLocation;

      final isPublicPath = path == '/onboarding' ||
          path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path == '/reset-password' ||
          path == '/payment-result' ||
          path.startsWith('/payment-webview');

      // First launch: not logged in AND not onboarded -> force onboarding
      if (!isLoggedIn && !onboardingDone && !isPublicPath) {
        return '/onboarding';
      }

      if (!isLoggedIn && !isPublicPath) {
        return '/login';
      }
      if (isLoggedIn && (path == '/login' || path == '/register' || path == '/onboarding')) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/brand/:id',
        builder: (context, state) => BrandDetailsScreen(brandId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/payment-webview',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return PaymentWebViewScreen(
            paymentUrl: extras['paymentUrl'] as String? ?? '',
            orderNumber: extras['orderNumber'] as String?,
          );
        },
      ),
      GoRoute(
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
          return ScaffoldWithNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/brands',
              builder: (context, state) {
                final search = state.uri.queryParameters['search'];
                final categories = state.uri.queryParameters['categories'];
                return BrandsScreen(initialSearch: search, initialCategory: categories);
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/distributor',
        builder: (context, state) => const DistributorScreen(),
      ),
      GoRoute(
        path: '/reseller',
        builder: (context, state) => const ResellerScreen(),
      ),
      GoRoute(
        path: '/corporate',
        builder: (context, state) => const CorporateScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: '/refund',
        builder: (context, state) => const RefundScreen(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/blogs',
        builder: (context, state) => const BlogScreen(),
      ),
      GoRoute(
        path: '/blogs/:id',
        builder: (context, state) => SingleBlogPage(id: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0),
      ),
      GoRoute(
        path: '/spin-wheel',
        builder: (context, state) => const SpinWheelScreen(),
      ),
      GoRoute(
        path: '/bulk-purchase',
        builder: (context, state) => const BulkPurchaseScreen(),
      ),
      GoRoute(
        path: '/nearby',
        builder: (context, state) => const NearbyScreen(),
      ),
    ],
  );
});
