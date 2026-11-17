import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/auth/data/app_lock_service.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';

enum AppLockStatus {
  /// Still checking prefs / session.
  checking,

  /// No session or lock not enabled — app is usable.
  unlocked,

  /// Session exists and lock is on — show unlock gate.
  locked,
}

class AppLockNotifier extends StateNotifier<AppLockStatus> {
  AppLockNotifier(this._service, this._ref) : super(AppLockStatus.checking) {
    _authSub = _ref.listen<AuthUser?>(authProvider, (previous, next) {
      if (next == null) {
        // Signed out — no lock overlay; next login starts unlocked.
        _unlockedThisRun = false;
        state = AppLockStatus.unlocked;
        return;
      }
      if (previous == null) {
        if (_unlockedThisRun || state == AppLockStatus.unlocked) {
          // Explicit login while app was already open — stay unlocked.
          _unlockedThisRun = true;
          state = AppLockStatus.unlocked;
        } else {
          // Cold restore (or still checking) — apply lock if enabled.
          Future.microtask(refresh);
        }
      }
    });
    _bootstrap();
  }

  final AppLockService _service;
  final Ref _ref;
  bool _pausedOnce = false;
  /// User unlocked (or freshly logged in) during this process lifetime.
  bool _unlockedThisRun = false;
  /// True while the system biometric sheet is open — ignore pause/resume.
  bool _biometricPromptActive = false;
  late final ProviderSubscription<AuthUser?> _authSub;

  bool get biometricPromptActive => _biometricPromptActive;

  void beginBiometricPrompt() => _biometricPromptActive = true;

  void endBiometricPrompt() => _biometricPromptActive = false;

  @override
  void dispose() {
    _authSub.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Wait until auth finished restoring the session.
    for (var i = 0; i < 40; i++) {
      if (_ref.read(authProvider.notifier).initialized) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await refresh();
  }

  Future<void> refresh() async {
    final user = _ref.read(authProvider);
    if (user == null) {
      state = AppLockStatus.unlocked;
      return;
    }
    if (_unlockedThisRun) {
      state = AppLockStatus.unlocked;
      return;
    }
    await _service.clearMpinIfUnset();
    final needsLock = await _service.requiresLock();
    state = needsLock ? AppLockStatus.locked : AppLockStatus.unlocked;
  }

  void unlock() {
    _unlockedThisRun = true;
    state = AppLockStatus.unlocked;
  }

  /// Call when app goes to background — re-lock if methods are enabled.
  Future<void> onAppPaused() async {
    // Biometric system UI pauses the app; do not treat that as "left unlocked".
    if (_biometricPromptActive) return;
    _pausedOnce = true;
    final user = _ref.read(authProvider);
    if (user == null) return;
    // Only lock when leaving an unlocked session (real background).
    if (state != AppLockStatus.unlocked) return;
    if (await _service.requiresLock()) {
      _unlockedThisRun = false;
      state = AppLockStatus.locked;
    }
  }

  Future<void> onAppResumed() async {
    if (_biometricPromptActive) return;
    if (!_pausedOnce) return;
    final user = _ref.read(authProvider);
    if (user == null) {
      state = AppLockStatus.unlocked;
      return;
    }
    // Do NOT re-lock on resume — that fights a biometric unlock that finished
    // while the system sheet had the app paused. Locking happens on pause only.
  }

  AppLockService get service => _service;
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockStatus>((ref) {
  return AppLockNotifier(ref.watch(appLockServiceProvider), ref);
});
