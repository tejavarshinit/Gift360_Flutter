import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';
import 'package:gift360/features/auth/presentation/providers/app_lock_provider.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';

/// Full-screen lock when a session is restored and biometric / MPIN is on.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  static const _maxBiometricFails = 3;

  String _pin = '';
  String _error = '';
  bool _busy = false;
  bool _biometricEnabled = false;
  bool _mpinEnabled = false;
  bool _autoBioTried = false;
  int _biometricFailCount = 0;
  bool _forceMpin = false;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  bool get _showMpinPad => _mpinEnabled && (_forceMpin || !_biometricEnabled);

  void _onBecameLocked() {
    setState(() {
      _pin = '';
      _error = '';
      _busy = false;
      _biometricFailCount = 0;
      _forceMpin = !_biometricEnabled && _mpinEnabled;
      _autoBioTried = false;
    });
    if (_biometricEnabled && !_forceMpin) {
      _autoBioTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlockWithBiometric();
      });
    }
  }

  Future<void> _loadMethods() async {
    final service = ref.read(appLockServiceProvider);
    await service.clearMpinIfUnset();
    final bio = await service.isBiometricLockEnabled();
    final mpin = await service.isMpinLockEnabled();
    if (!mounted) return;

    // Nothing valid to unlock with — don't block the app.
    if (!bio && !mpin) {
      ref.read(appLockProvider.notifier).unlock();
      return;
    }

    setState(() {
      _biometricEnabled = bio;
      _mpinEnabled = mpin;
      _forceMpin = !bio && mpin;
    });
    if (bio && !_autoBioTried && !_forceMpin) {
      _autoBioTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlockWithBiometric();
      });
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_busy || _forceMpin) return;
    final lockNotifier = ref.read(appLockProvider.notifier);
    setState(() {
      _busy = true;
      _error = '';
    });
    lockNotifier.beginBiometricPrompt();
    try {
      // Safety: never leave the UI stuck disabled if the sheet hangs.
      await ref
          .read(appLockServiceProvider)
          .authenticateWithBiometrics()
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      _biometricFailCount = 0;
      _forceMpin = false;
      lockNotifier.unlock();
    } on BiometricException catch (e) {
      if (!mounted) return;
      _handleBiometricFailure(e.message);
    } catch (e) {
      if (!mounted) return;
      _handleBiometricFailure(e.toString());
    } finally {
      lockNotifier.endBiometricPrompt();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchToMpin() {
    ref.read(appLockProvider.notifier).endBiometricPrompt();
    setState(() {
      _busy = false;
      _forceMpin = true;
      _error = '';
      _pin = '';
      _autoBioTried = true;
    });
  }

  void _handleBiometricFailure(String message) {
    _biometricFailCount += 1;
    if (_biometricFailCount >= _maxBiometricFails) {
      // Only switch to MPIN when the user actually set one.
      if (_mpinEnabled) {
        setState(() {
          _forceMpin = true;
          _error =
              'Biometric failed $_maxBiometricFails times. Enter your MPIN.';
          _busy = false;
        });
      } else {
        setState(() {
          _error =
              'Biometric failed $_maxBiometricFails times. Try again or sign out.';
          _busy = false;
          _biometricFailCount = 0;
        });
      }
      return;
    }
    setState(() {
      _error = _mpinEnabled
          ? '$message (${_maxBiometricFails - _biometricFailCount} tries left)'
          : message;
      _busy = false;
    });
  }

  void _onDigit(String d) {
    if (_pin.length >= 4 || _busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = '';
    });
    if (_pin.length == 4) {
      _tryAutoSubmit();
    }
  }

  Future<void> _tryAutoSubmit() async {
    if (_pin.length != 4) return;
    final ok = await ref.read(appLockServiceProvider).verifyMpin(_pin);
    if (!mounted) return;
    if (ok) {
      ref.read(appLockProvider.notifier).unlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Incorrect MPIN. Try again.';
        _pin = '';
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLockStatus>(appLockProvider, (prev, next) {
      if (next == AppLockStatus.locked && prev != AppLockStatus.locked) {
        _onBecameLocked();
      }
    });

    final status = ref.watch(appLockProvider);
    if (status != AppLockStatus.locked) {
      return const SizedBox.shrink();
    }

    final user = ref.watch(authProvider);
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'there';

    // Fully opaque so home / chat never show "through" the lock.
    return Material(
      color: const Color(0xFFF8F7FB),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 36),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 36,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Welcome back, $name',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F1635),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _showMpinPad
                    ? 'Enter your MPIN to unlock'
                    : 'Use biometrics to unlock Gift360',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF81789A),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
              if (_showMpinPad) ...[
                const SizedBox(height: 28),
                _MpinDots(filledCount: _pin.length, length: 4),
                const SizedBox(height: 28),
                _PinPad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  enabled: !_busy,
                ),
              ],
              const Spacer(),
              if (_biometricEnabled && !_forceMpin)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _unlockWithBiometric,
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: Text(
                      _busy ? 'Waiting for biometrics…' : 'Unlock with biometrics',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primaryPurple.withValues(alpha: 0.45),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (_biometricEnabled &&
                  _mpinEnabled &&
                  !_forceMpin &&
                  !_showMpinPad) ...[
                const SizedBox(height: 10),
                TextButton(
                  // Always tappable — even while biometric sheet is busy/stuck.
                  onPressed: _switchToMpin,
                  child: Text(
                    'Use MPIN instead',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final lock = ref.read(appLockServiceProvider);
                  await lock.setMpinLockEnabled(false);
                  await lock.setBiometricLockEnabled(false);
                  await ref.read(authProvider.notifier).logout();
                  ref.read(appLockProvider.notifier).unlock();
                },
                child: Text(
                  'Sign out',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF81789A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    final width = MediaQuery.sizeOf(context).width;
    final keySize = ((width - 72) / 3).clamp(72.0, 96.0);

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return SizedBox(width: keySize, height: keySize * 0.72);
              }
              final isBackspace = key == '⌫';
              return SizedBox(
                width: keySize,
                height: keySize * 0.72,
                child: Material(
                  color: isBackspace
                      ? const Color(0xFFF0ECF7)
                      : Colors.white,
                  elevation: isBackspace ? 0 : 1.5,
                  shadowColor: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: !enabled
                        ? null
                        : () {
                            if (isBackspace) {
                              onBackspace();
                            } else {
                              onDigit(key);
                            }
                          },
                    child: Center(
                      child: isBackspace
                          ? const Icon(
                              Icons.backspace_outlined,
                              size: 22,
                              color: Color(0xFF5B5270),
                            )
                          : Text(
                              key,
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F1635),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Full-screen create / confirm MPIN (exactly 4 digits + keypad).
Future<String?> showSetMpinDialog(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    PageRouteBuilder<String>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _SetMpinScreen();
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    ),
  );
}

class _SetMpinScreen extends StatefulWidget {
  const _SetMpinScreen();

  @override
  State<_SetMpinScreen> createState() => _SetMpinScreenState();
}

class _SetMpinScreenState extends State<_SetMpinScreen> {
  static const _pinLength = 4;

  String _first = '';
  String _confirm = '';
  bool _confirming = false;
  String _error = '';

  String get _activePin => _confirming ? _confirm : _first;

  void _onDigit(String d) {
    if (_activePin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = '';
      if (_confirming) {
        _confirm += d;
      } else {
        _first += d;
      }
    });
    if (_activePin.length == _pinLength) {
      _onPinComplete();
    }
  }

  void _onBackspace() {
    if (_activePin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = '';
      if (_confirming) {
        _confirm = _confirm.substring(0, _confirm.length - 1);
      } else {
        _first = _first.substring(0, _first.length - 1);
      }
    });
  }

  Future<void> _onPinComplete() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    if (!_confirming) {
      setState(() {
        _confirming = true;
        _confirm = '';
        _error = '';
      });
      return;
    }

    if (_confirm != _first) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'MPINs do not match. Try again.';
        _confirming = false;
        _first = '';
        _confirm = '';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(_first);
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + bottom),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF81789A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryPurple.withValues(alpha: 0.18),
                      AppColors.primaryBlue.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.pin_rounded,
                  size: 40,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _confirming ? 'Confirm your MPIN' : 'Create your MPIN',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F1635),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _confirming
                    ? 'Re-enter the same 4-digit MPIN'
                    : 'Set a 4-digit MPIN to unlock Gift360 next time',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.4,
                  color: const Color(0xFF81789A),
                ),
              ),
              const SizedBox(height: 36),
              _MpinDots(
                filledCount: _activePin.length,
                length: _pinLength,
                hasError: _error.isNotEmpty,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
              const Spacer(),
              _PinPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                enabled: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${_confirming ? 2 : 1} of 2',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFA39BB8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MpinDots extends StatelessWidget {
  final int filledCount;
  final int length;
  final bool hasError;

  const _MpinDots({
    required this.filledCount,
    required this.length,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final filled = i < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: filled ? 16 : 14,
          height: filled ? 16 : 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (hasError ? Colors.red.shade500 : AppColors.primaryPurple)
                : Colors.transparent,
            border: Border.all(
              color: hasError
                  ? Colors.red.shade300
                  : filled
                      ? AppColors.primaryPurple
                      : const Color(0xFFD5CEE6),
              width: 2,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
