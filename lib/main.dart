import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/providers/notification_provider.dart';
import 'core/widgets/gift_header.dart';
import 'config/app_config.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/supercoin/presentation/providers/supercoin_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  
  // Debug: verify env loaded
  assert(() {
    print('ENV DEBUG: AUTH_API_URL = ${AppConfig.authApiUrl}');
    print('ENV DEBUG: BRAND_API_URL = ${AppConfig.brandApiUrl}');
    return true;
  }());

  bool onboardingComplete = false;
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    onboardingComplete = prefs.getBool('g360_onboarding_v3') ?? false;
  } catch (_) {
    onboardingComplete = false;
  }

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteProvider.overrideWith((ref) => OnboardingNotifier(onboardingComplete)),
        if (prefs != null)
          notificationProvider.overrideWith((ref) => NotificationNotifier(prefs!)),
      ],
      child: const Gift360App(),
    ),
  );
}

class Gift360App extends ConsumerStatefulWidget {
  const Gift360App({super.key});

  @override
  ConsumerState<Gift360App> createState() => _Gift360AppState();
}

class _Gift360AppState extends ConsumerState<Gift360App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire up 401 session expiry handler
    DioClient.onSessionExpired = () {
      _handleSessionExpired();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When app goes to inactive/background, release any active SuperCoin holds
  /// (mirrors React's sendBeacon on beforeunload).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _releaseActiveSuperCoinHolds();
    }
  }

  void _releaseActiveSuperCoinHolds() async {
    try {
      final holdContext = await SuperCoinOtpNotifier.loadHoldContext('active');
      if (holdContext != null) {
        final api = ref.read(supercoinApiProvider);
        final user = ref.read(authProvider);
        if (user != null) {
          final normalized = _normalizeMobile(user.mobile);
          if (normalized != null) {
            await api.unhold({
              'identity': {'identifier': normalized, 'type': 'MOBILE'},
              'merchantTransactionId': holdContext.merchantTransactionId,
              'merchantWalletId': holdContext.merchantWalletId,
            });
          }
        }
        await SuperCoinOtpNotifier.clearHoldContext('active');
      }
    } catch (_) {
      // Best effort — don't crash on background release
    }
  }

  String? _normalizeMobile(String mobile) {
    final trimmed = mobile.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+') && digits.length >= 10) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return trimmed.startsWith('+') ? trimmed : '+${digits.isNotEmpty ? digits : trimmed}';
  }

  void _handleSessionExpired() {
    // Use addPostFrameCallback to ensure we're in a valid frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      final currentContext = navigatorKey.currentContext;
      if (currentContext == null) return;

      // Don't show dialog if already on login/onboarding
      final currentPath = GoRouterState.of(currentContext).matchedLocation;
      if (currentPath == '/login' || currentPath == '/onboarding' || currentPath == '/register') {
        return;
      }

      // Clear cart merge flag (forces fresh merge on next login, matches React)
      try {
        final user = ref.read(authProvider);
        if (user?.clientId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cart_merged_${user!.clientId}');
        }
      } catch (_) {}

      // Logout the user
      ref.read(authProvider.notifier).logout();

      // Show session expired dialog
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Session Expired'),
          content: const Text('Your session has expired. Please log in again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                GoRouter.of(currentContext).go('/login');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Gift360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Ensure navigatorKey is available for 401 handler
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Global navigator key for 401 handler to access context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
