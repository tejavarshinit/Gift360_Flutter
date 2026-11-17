import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/app_navigator.dart';
import 'core/navigation/system_back_exit_guard.dart';
import 'core/widgets/global_support_chat_overlay.dart';
import 'core/network/dio_client.dart';
import 'core/providers/notification_provider.dart';
import 'core/widgets/gift_header.dart';
import 'core/widgets/session_expired_dialog.dart';
import 'config/app_config.dart';
import 'config/app_flavor.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/providers/app_lock_provider.dart';
import 'features/auth/presentation/widgets/app_lock_gate.dart';
import 'features/auth/data/models/auth_user.dart';
import 'features/notifications/data/repositories/device_token_api.dart';
import 'features/notifications/presentation/services/push_notification_service.dart';
import 'features/supercoin/presentation/providers/supercoin_provider.dart';
import 'features/rewards/data/app_install_reward_service.dart';
import 'features/rewards/presentation/providers/rewards_provider.dart';
import 'features/rewards/presentation/widgets/app_install_reward_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Prod uses .env.prod. The shared .env stays blank so dev does not
    // call live servers. flutter_dotenv keeps the first value for a key,
    // so these files must not be merged.
    if (AppFlavorConfig.isProd) {
      await dotenv.load(fileName: '.env.prod');
    } else {
      await dotenv.load(isOptional: true);
    }
  } catch (error, stackTrace) {
    // Dev has no API file yet. Staging and prod must have .env.
    if (!AppFlavorConfig.isDev) {
      debugPrint('[ENV] Failed to load .env: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
    debugPrint('[ENV] Dev build started without .env');
  }

  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    firebaseAvailable = true;
  } catch (error, stackTrace) {
    debugPrint('[FCM] Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Debug: verify env loaded
  assert(() {
    debugPrint('ENV DEBUG: AUTH_API_URL = ${AppConfig.authApiUrl}');
    debugPrint('ENV DEBUG: BRAND_API_URL = ${AppConfig.brandApiUrl}');
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

  final pushNotificationService = PushNotificationService(
    firebaseAvailable: firebaseAvailable,
    deviceTokenApi: DeviceTokenApi(baseUrl: AppConfig.notificationApiBaseUrl),
  );

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteProvider.overrideWith(
          (ref) => OnboardingNotifier(onboardingComplete),
        ),
        if (prefs != null)
          notificationProvider.overrideWith(
            (ref) => NotificationNotifier(prefs!),
          ),
        pushNotificationServiceProvider.overrideWithValue(
          pushNotificationService,
        ),
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

class _Gift360AppState extends ConsumerState<Gift360App>
    with WidgetsBindingObserver {
  late final PushNotificationService _pushNotificationService;
  late final AppInstallRewardService _installRewardService;
  ProviderSubscription<AuthUser?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushNotificationService = ref.read(pushNotificationServiceProvider);
    _pushNotificationService.setNavigationHandler(
      (destination) => ref.read(goRouterProvider).go(destination),
    );
    _pushNotificationService.updateAuthenticatedUser(ref.read(authProvider));
    _installRewardService = AppInstallRewardService(
      ref.read(rewardsApiProvider),
    );
    _authSubscription = ref.listenManual<AuthUser?>(authProvider, (
      previous,
      user,
    ) {
      _pushNotificationService.updateAuthenticatedUser(user);
      if (user != null && previous?.clientId != user.clientId) {
        unawaited(_claimInstallReward(user));
      }
    });
    unawaited(_requestAppPermissions());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushNotificationService.setNavigationReady(true);
      unawaited(_claimInstallRewardForCurrentUser());
    });
    // Wire up 401 session expiry handler
    DioClient.onSessionExpired = () {
      _handleSessionExpired();
    };
  }

  Future<void> _requestAppPermissions() async {
    final notificationsReady = _pushNotificationService.initialize();
    // Show the location prompt right after the notification prompt instead of
    // waiting for FCM token upload to finish.
    await _pushNotificationService.permissionRequested;
    await _requestInitialLocationPermission();
    await notificationsReady;
  }

  Future<void> _requestInitialLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (error) {
      debugPrint('[Location] Initial permission request error: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.close();
    _pushNotificationService.dispose();
    super.dispose();
  }

  /// When app goes to inactive/background, release any active SuperCoin holds
  /// (mirrors React's sendBeacon on beforeunload).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseActiveSuperCoinHolds();
      if (state == AppLifecycleState.paused) {
        unawaited(ref.read(appLockProvider.notifier).onAppPaused());
      }
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(appLockProvider.notifier).onAppResumed());
      unawaited(_claimInstallRewardForCurrentUser());
    }
  }

  Future<void> _claimInstallRewardForCurrentUser() async {
    final user = ref.read(authProvider);
    if (user != null) await _claimInstallReward(user);
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

  Future<void> _claimInstallReward(AuthUser user) async {
    if (kIsWeb) return;
    final result = await _installRewardService.claimIfEligible(user.clientId);
    if (result.status == 'flipkart_user_not_found') {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message!)));
      }
      return;
    }
    final coins = result.coins;
    if (coins == null || coins <= 0) return;

    ref.read(authProvider.notifier).refreshSuperCoinBalance();
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) return;
      final context = navigatorKey.currentContext;
      if (context != null) {
        final path = ref
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path;
        const authPaths = {
          '/login',
          '/register',
          '/onboarding',
          '/forgot-password',
          '/reset-password',
        };
        if (path.isNotEmpty && !authPaths.contains(path)) {
          if (!context.mounted) return;
          await AppInstallRewardDialog.show(context, coins);
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  String? _normalizeMobile(String mobile) {
    final trimmed = mobile.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+') && digits.length >= 10) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return trimmed.startsWith('+')
        ? trimmed
        : '+${digits.isNotEmpty ? digits : trimmed}';
  }

  void _handleSessionExpired() {
    // Use addPostFrameCallback to ensure we're in a valid frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final currentContext = navigatorKey.currentContext;
      if (currentContext == null) return;

      // Don't show dialog if already on login/onboarding
      final currentPath = GoRouterState.of(currentContext).matchedLocation;
      if (currentPath == '/login' ||
          currentPath == '/onboarding' ||
          currentPath == '/register') {
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

      if (!currentContext.mounted) return;

      // Logout the user
      ref.read(authProvider.notifier).logout();

      // Show session expired dialog
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (ctx) => SessionExpiredDialog(
          onLoginRedirect: () {
            Navigator.of(ctx).pop();
            GoRouter.of(currentContext).go('/login?session=expired');
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return SystemBackExitGuard(
      child: MaterialApp.router(
        title: 'Gift360',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) {
          // Keep type readable on large system font sizes without blowing
          // fixed phone layouts apart. Overlays sit above the navigator.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.25,
              ),
            ),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const GlobalSupportChatOverlay(),
                const AppLockGate(),
              ],
            ),
          );
        },
      ),
    );
  }
}

