import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/providers/notification_provider.dart';
import 'core/widgets/gift_header.dart';
import 'config/app_config.dart';

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
        onboardingCompleteProvider.overrideWithValue(onboardingComplete),
        if (prefs != null)
          notificationProvider.overrideWith((ref) => NotificationNotifier(prefs!)),
      ],
      child: const Gift360App(),
    ),
  );
}

class Gift360App extends ConsumerWidget {
  const Gift360App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Gift360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
