import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfigNotifier extends StateNotifier<Map<String, dynamic>> {
  AppConfigNotifier() : super({});

  void updateConfig(Map<String, dynamic> config) {
    state = config;
  }

  bool isFeatureEnabled(String feature) {
    return state[feature] ?? true;
  }
}

final appConfigProvider =
    StateNotifierProvider<AppConfigNotifier, Map<String, dynamic>>(
  (ref) => AppConfigNotifier(),
);

