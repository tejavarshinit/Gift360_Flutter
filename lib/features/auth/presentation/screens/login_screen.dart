import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/constants/app_constants.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/config/app_flavor.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';
import 'package:gift360/features/auth/presentation/providers/app_lock_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/auth/presentation/widgets/app_lock_gate.dart';
import 'package:gift360/features/auth/presentation/widgets/diwali_auth_shell.dart';
import 'package:gift360/features/profile/data/profile_details_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginMethod {
  otp,
  biometric,
  mpin,
}

class LoginScreen extends ConsumerStatefulWidget {
  final bool isSessionExpired;
  const LoginScreen({super.key, this.isSessionExpired = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  LoginMethod _selectedMethod = LoginMethod.otp;
  bool _enableBiometricOnOtp = true;
  bool _otpSent = false;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  String _otpMessage = '';
  String _error = '';
  String _mobileError = '';
  String _termsError = '';
  bool _biometricEnrolled = false;
  bool _biometricFingerprintAvailable = true;
  bool _biometricCredentialAvailable = true;
  String? _biometricIssue;
  bool _autoAuthTriggered = false;

  bool _isOtpConfigured = true;
  bool _isBiometricConfigured = true;
  bool _isMpinConfigured = true;

  bool get _showOtpMethod => _isOtpConfigured;
  bool get _showBiometricMethod =>
      AppConfig.biometricLoginEnabled && _isBiometricConfigured;
  bool get _showMpinMethod =>
      AppConfig.biometricLoginEnabled && _isMpinConfigured;

  @override
  void initState() {
    super.initState();
    if (AppConfig.biometricLoginEnabled) _loadBiometricState();
    if (widget.isSessionExpired) {
      _error = 'Your session has expired. Please login again.';
    }
  }

  Future<void> _loadBiometricState() async {
    try {
      final service = ref.read(biometricServiceProvider);
      final state = await service.enrollmentState();
      final availability = await service.availability();
      final prefs = await SharedPreferences.getInstance();

      final otpConfigured = prefs.getBool('login_method_otp_enabled') ?? true;
      final biometricConfigured =
          prefs.getBool('login_method_biometric_enabled') ?? true;
      final mpinConfigured =
          prefs.getBool('login_method_mpin_enabled') ?? true;

      var effectiveOtp = otpConfigured;
      var effectiveBiometric = biometricConfigured;
      var effectiveMpin = mpinConfigured;
      if (!effectiveOtp && !effectiveBiometric && !effectiveMpin) {
        effectiveOtp = true;
      }

      if (!mounted) return;
      setState(() {
        _biometricEnrolled = state.isEnabled;
        _biometricIssue = state.issue;
        _biometricFingerprintAvailable = availability.biometricAvailable;
        _biometricCredentialAvailable = availability.credentialAvailable;
        _isOtpConfigured = effectiveOtp;
        _isBiometricConfigured = effectiveBiometric;
        _isMpinConfigured = effectiveMpin;
        // Keep setup-on-login checked by default for new users.
        _enableBiometricOnOtp = true;

        // Automatically select the best enabled method based on profile preferences
        if (_biometricEnrolled &&
            _isBiometricConfigured &&
            _biometricFingerprintAvailable) {
          _selectedMethod = LoginMethod.biometric;
        } else if (_biometricEnrolled &&
            _isMpinConfigured &&
            _biometricCredentialAvailable) {
          _selectedMethod = LoginMethod.mpin;
        } else if (_isOtpConfigured) {
          _selectedMethod = LoginMethod.otp;
        } else if (_isBiometricConfigured) {
          _selectedMethod = LoginMethod.biometric;
        } else {
          _selectedMethod = LoginMethod.mpin;
        }
      });
      // Ask biometric / device MPIN immediately — no button tap needed.
      _scheduleAutoAuth();
    } catch (error) {
      if (!mounted) return;
      setState(() => _biometricIssue = error.toString());
    }
  }

  void _scheduleAutoAuth() {
    if (_autoAuthTriggered || _isLoading || !_biometricEnrolled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoAuthTriggered || _isLoading) return;
      if (_selectedMethod == LoginMethod.biometric &&
          _biometricFingerprintAvailable) {
        _autoAuthTriggered = true;
        _handleBiometricLogin(DeviceAuthMethod.biometric);
      } else if (_selectedMethod == LoginMethod.mpin &&
          _biometricCredentialAvailable) {
        _autoAuthTriggered = true;
        _handleBiometricLogin(DeviceAuthMethod.deviceCredential);
      }
    });
  }

  Future<void> _handleBiometricLogin(DeviceAuthMethod method) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final result = await ref.read(biometricServiceProvider).login(
        method: method,
      );
      await ref.read(authProvider.notifier).loginWithBiometrics(result);
      if (mounted) await _goAfterLogin();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
          _isLoading = false;
        });
      }
    }
  }

  /// New / incomplete profiles fill Name, Email, Gender, DOB before home.
  Future<void> _goAfterLogin() async {
    final user = ref.read(authProvider);
    if (user != null && await ProfileDetailsStore.isIncomplete(user)) {
      if (mounted) context.go('/profile/details?setup=1');
      return;
    }
    if (mounted) context.go('/');
  }

  /// After OTP, set up device biometric + user MPIN on this screen.
  Future<void> _setupUnlockAfterOtpLogin() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null || !mounted) return;

    if (!AppFlavorConfig.isDev) {
      try {
        await ref.read(biometricServiceProvider).resetAndEnable(
              clientId: currentUser.clientId,
              token: currentUser.token,
            );
      } catch (bioError) {
        debugPrint('Biometric auto-enable error: $bioError');
      }
    }

    if (!mounted) return;
    final lock = ref.read(appLockServiceProvider);

    // Prompt biometrics right away (permission / Face ID / fingerprint).
    if (!await lock.isBiometricLockEnabled()) {
      final lockNotifier = ref.read(appLockProvider.notifier);
      lockNotifier.beginBiometricPrompt();
      try {
        await lock.authenticateWithBiometrics(
          reason: 'Enable biometric unlock for Gift360',
        );
        await lock.setBiometricLockEnabled(true);
      } catch (e) {
        debugPrint('App biometric lock setup skipped: $e');
      } finally {
        lockNotifier.endBiometricPrompt();
      }
    }

    // Then ask to create MPIN if not already set — stay on login for this.
    if (!mounted) return;
    if (!await lock.hasMpinSet()) {
      if (!mounted) return;
      final pin = await showSetMpinDialog(context);
      if (pin != null && pin.isNotEmpty) {
        try {
          await lock.setMpin(pin);
        } catch (e) {
          debugPrint('MPIN setup skipped: $e');
        }
      } else {
        // User cancelled — never leave MPIN lock half-enabled.
        await lock.clearMpinIfUnset();
      }
    }

    // Stay unlocked for this session; lock applies next background / reopen.
    if (mounted) {
      ref.read(appLockProvider.notifier).unlock();
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool _validateMobile(String m) => AppConstants.mobileRegex.hasMatch(m);
  bool _validateOtp() => _otpControllers.every((c) => c.text.length == 1);

  String get _otpString => _otpControllers.map((c) => c.text).join();

  void _clearErrors() {
    setState(() {
      _error = '';
      _mobileError = '';
      _termsError = '';
    });
  }

  void _handleOtpInput(int index, String value) {
    if (!RegExp(r'^[0-9]?$').hasMatch(value)) return;
    setState(() {});
    if (value.isNotEmpty && index < 3) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  void _onSelectMethod(LoginMethod method) {
    if (_isLoading) return;
    setState(() {
      _selectedMethod = method;
      _error = '';
      _mobileError = '';
      _otpSent = false;
      _otpMessage = '';
      for (final c in _otpControllers) {
        c.clear();
      }
    });
    // Switching to Biometric / MPIN should prompt immediately.
    if (_biometricEnrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isLoading) return;
        if (method == LoginMethod.biometric &&
            _biometricFingerprintAvailable) {
          _handleBiometricLogin(DeviceAuthMethod.biometric);
        } else if (method == LoginMethod.mpin &&
            _biometricCredentialAvailable) {
          _handleBiometricLogin(DeviceAuthMethod.deviceCredential);
        }
      });
    }
  }

  Future<void> _handleSendOtp() async {
    final mobile = _mobileController.text.trim();
    _clearErrors();
    setState(() {
      _otpMessage = '';
      _otpSent = false;
      for (final c in _otpControllers) {
        c.clear();
      }
    });

    if (mobile.isEmpty) {
      setState(() => _mobileError = 'Mobile number is required');
      return;
    }
    if (!_validateMobile(mobile)) {
      setState(
        () => _mobileError = 'Please enter a valid 10-digit mobile number',
      );
      return;
    }
    if (!_acceptedTerms) {
      setState(
        () => _termsError =
            'Please accept the Terms & Conditions and Privacy Policy',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(authProvider.notifier)
          .sendOtp(SendOtpRequest(mobileNumber: mobile));
      if (response.notRegistered == true) {
        setState(() {
          _error = 'Mobile number not registered. Please register first.';
          _isLoading = false;
        });
        return;
      }
      if (response.success) {
        setState(() {
          _otpSent = true;
          _otpMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleOtpLogin() async {
    final mobile = _mobileController.text.trim();
    final otp = _otpString;
    _clearErrors();

    if (!_validateMobile(mobile)) {
      setState(() => _error = 'Please enter a valid mobile number');
      return;
    }
    if (!_validateOtp()) {
      setState(() => _error = 'Please enter a valid 4-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    final needsUnlockSetup =
        _enableBiometricOnOtp && AppConfig.biometricLoginEnabled;
    if (needsUnlockSetup) {
      // Keep /login mounted until biometric + MPIN dialogs finish.
      ref.read(postLoginSetupHoldingProvider.notifier).state = true;
    }
    try {
      final response = await ref
          .read(authProvider.notifier)
          .loginWithOtp(LoginWithOtpRequest(mobileNumber: mobile, otp: otp));
      if (response.success && response.token != null) {
        if (needsUnlockSetup) {
          await _setupUnlockAfterOtpLogin();
        } else if (!AppFlavorConfig.isDev &&
            AppConfig.biometricLoginEnabled &&
            _biometricEnrolled) {
          final currentUser = ref.read(authProvider);
          if (currentUser != null) {
            try {
              await ref.read(biometricServiceProvider).disable(
                    clientId: currentUser.clientId,
                    token: currentUser.token,
                  );
            } catch (bioError) {
              debugPrint('Biometric disable error: $bioError');
            }
          }
        }
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) await _goAfterLogin();
        }
      } else if (mounted) {
        setState(() {
          _error = response.message.isNotEmpty
              ? response.message
              : 'OTP login failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
          _isLoading = false;
        });
      }
    } finally {
      if (needsUnlockSetup) {
        ref.read(postLoginSetupHoldingProvider.notifier).state = false;
      }
    }
  }

  /// Registers Biometric or MPIN directly on this tab without requiring a separate sign-in.
  Future<void> _handleRegisterDeviceAuth(DeviceAuthMethod method) async {
    final mobile = _mobileController.text.trim();
    final otp = _otpString;
    _clearErrors();

    if (!_validateMobile(mobile)) {
      setState(() => _error = 'Please enter a valid mobile number');
      return;
    }
    if (!_validateOtp()) {
      setState(() => _error = 'Please enter the 4-digit verification code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Authenticate mobile number to obtain authorization token
      final response = await ref
          .read(authProvider.notifier)
          .loginWithOtp(LoginWithOtpRequest(mobileNumber: mobile, otp: otp));

      if (!response.success || response.token == null) {
        setState(() {
          _error = response.message.isNotEmpty
              ? response.message
              : 'Verification failed. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // 2. Register device key in secure hardware and link to account.
      // Dev has no auth gateway, so the local OTP session stands on its own.
      final currentUser = ref.read(authProvider);
      if (!AppFlavorConfig.isDev &&
          currentUser != null &&
          AppConfig.biometricLoginEnabled) {
        await ref.read(biometricServiceProvider).resetAndEnable(
              clientId: currentUser.clientId,
              token: currentUser.token,
            );
        setState(() {
          _biometricEnrolled = true;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              method == DeviceAuthMethod.biometric
                  ? 'Biometric login registered successfully!'
                  : 'Device MPIN login registered successfully!',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) await _goAfterLogin();
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('No API address')) {
      return 'Login server is not configured in this build.';
    }
    if (msg.contains('connection error') ||
        msg.contains('No internet') ||
        msg.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('connection timeout') || msg.contains('receive timeout')) {
      return 'Connection timed out. Please try again.';
    }
    if (msg.contains('404')) {
      return 'Service not found. Please try again later.';
    }
    if (msg.contains('500')) return 'Server error. Please try again later.';
    if (msg.contains('401') || msg.contains('403')) {
      return 'Invalid credentials or code expired. Please try again.';
    }
    if (msg.length > 120) return 'Something went wrong. Please try again.';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return DiwaliAuthShell(
      switchPrompt: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3F1A55),
          ),
          children: [
            const TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: 'Sign up',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD4650F),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.go('/register'),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error.isNotEmpty) _buildAlert(_error),
          if (AppConfig.biometricLoginEnabled &&
              _biometricIssue != null &&
              _selectedMethod != LoginMethod.otp)
            _buildAlert('$_biometricIssue You can register again or use OTP.'),
          _buildMethodSelector(),
          _buildSelectedMethodView(),
        ],
      ),
    );
  }

  // ── Method Selector Tabs ──
  Widget _buildMethodSelector() {
    final tabs = <Widget>[];
    if (_showOtpMethod) {
      tabs.add(
        Expanded(
          child: _buildTabButton(
            method: LoginMethod.otp,
            label: 'OTP',
            icon: Icons.sms_outlined,
          ),
        ),
      );
    }
    if (_showBiometricMethod) {
      tabs.add(
        Expanded(
          child: _buildTabButton(
            method: LoginMethod.biometric,
            label: 'Biometric',
            icon: Icons.fingerprint_rounded,
            showBadge: _biometricEnrolled && _biometricFingerprintAvailable,
          ),
        ),
      );
    }
    if (_showMpinMethod) {
      tabs.add(
        Expanded(
          child: _buildTabButton(
            method: LoginMethod.mpin,
            label: 'MPIN',
            icon: Icons.dialpad_rounded,
            showBadge: _biometricEnrolled && _biometricCredentialAvailable,
          ),
        ),
      );
    }
    if (tabs.length < 2) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < tabs.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 4));
      children.add(tabs[i]);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5DCF0)),
      ),
      child: Row(children: children),
    );
  }

  Widget _buildTabButton({
    required LoginMethod method,
    required String label,
    required IconData icon,
    bool showBadge = false,
  }) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => _onSelectMethod(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7B3DC3), Color(0xFF5537BE)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x337B3DC3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF4A4458),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF4A4458),
                  ),
                ),
              ],
            ),
            if (showBadge)
              Positioned(
                top: 5,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Selected Method Content ──
  Widget _buildSelectedMethodView() {
    switch (_selectedMethod) {
      case LoginMethod.biometric:
        return _buildBiometricView();
      case LoginMethod.mpin:
        return _buildMpinView();
      case LoginMethod.otp:
        return _buildOtpView();
    }
  }

  // ── OTP View ──
  Widget _buildOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileInput(),
        if (_mobileError.isNotEmpty) _buildErrorText(_mobileError),
        _buildTermsCheckbox(),
        if ((_showBiometricMethod || _showMpinMethod) && !_otpSent)
          _buildBiometricEnableToggle(),
        const SizedBox(height: 8),
        if (!_otpSent)
          _buildActionButton(
            label: _isLoading ? 'Sending...' : 'Send OTP',
            icon: Icons.send_rounded,
            onTap: (_isLoading ||
                    !_acceptedTerms ||
                    !_validateMobile(_mobileController.text))
                ? null
                : _handleSendOtp,
          )
        else
          _buildOtpInputSection(
            verifyButtonLabel: 'Verify & Login',
            onVerify: _handleOtpLogin,
            extraNotice:
                _enableBiometricOnOtp &&
                    (_showBiometricMethod || _showMpinMethod)
                ? 'Biometric & MPIN will be enabled upon sign in'
                : null,
          ),
        if (_otpMessage.isNotEmpty && _otpSent)
          _buildSuccessText(_otpMessage),
      ],
    );
  }

  Widget _buildBiometricEnableToggle() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFECE6F4)),
      ),
      child: InkWell(
        onTap: () => setState(
          () => _enableBiometricOnOtp = !_enableBiometricOnOtp,
        ),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _enableBiometricOnOtp,
                onChanged: (v) =>
                    setState(() => _enableBiometricOnOtp = v ?? true),
                activeColor: const Color(0xFF7B3DC3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Biometric & MPIN login',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3F1A55),
                    ),
                  ),
                  Text(
                    'Fast 1-tap fingerprint or MPIN for next time',
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Biometric View ──
  Widget _buildBiometricView() {
    if (_biometricEnrolled) {
      if (!_biometricFingerprintAvailable) {
        return _buildUnavailableState(
          title: 'Biometric Not Available',
          description:
              'Fingerprint / face sensor is not available on this device.',
          buttonText: 'Login with MPIN Instead',
          onTapButton: () => _onSelectMethod(LoginMethod.mpin),
          secondaryText: 'Or login with OTP',
          onTapSecondary: () => _onSelectMethod(LoginMethod.otp),
        );
      }
      return Column(
        children: [
          const SizedBox(height: 4),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: const Center(
              child: Icon(
                Icons.fingerprint_rounded,
                size: 32,
                color: Color(0xFF7B3DC3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Biometric Login',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3F1A55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Touch sensor or glance at camera to sign in',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          _buildActionButton(
            label: _isLoading
                ? 'Authenticating...'
                : 'Authenticate with Biometrics',
            icon: Icons.fingerprint_rounded,
            onTap: _isLoading
                ? null
                : () => _handleBiometricLogin(DeviceAuthMethod.biometric),
          ),
          const SizedBox(height: 8),
          _buildOtherMethodLinks(LoginMethod.biometric),
        ],
      );
    }

    // ── First-time Registration Directly on this Tab ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD8B4FE)),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 18,
                color: Color(0xFF7B3DC3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Biometric Login',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3F1A55),
                    ),
                  ),
                  Text(
                    'Set up 1-tap fingerprint or face sign-in',
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildMobileInput(),
        if (_mobileError.isNotEmpty) _buildErrorText(_mobileError),
        _buildTermsCheckbox(),
        const SizedBox(height: 8),
        if (!_otpSent)
          _buildActionButton(
            label: _isLoading ? 'Sending Code...' : 'Register Biometric',
            icon: Icons.fingerprint_rounded,
            onTap: (_isLoading ||
                    !_acceptedTerms ||
                    !_validateMobile(_mobileController.text))
                ? null
                : _handleSendOtp,
          )
        else
          _buildOtpInputSection(
            verifyButtonLabel: 'Verify & Activate Biometric',
            onVerify: () =>
                _handleRegisterDeviceAuth(DeviceAuthMethod.biometric),
            extraNotice: 'Enter verification code to activate biometric login',
          ),
        if (_otpMessage.isNotEmpty && _otpSent)
          _buildSuccessText(_otpMessage),
      ],
    );
  }

  // ── MPIN View ──
  Widget _buildMpinView() {
    if (_biometricEnrolled) {
      if (!_biometricCredentialAvailable) {
        return _buildUnavailableState(
          title: 'Screen Lock Not Configured',
          description:
              'No screen lock PIN or pattern is set on this device. Please set up a screen lock in settings.',
          buttonText: 'Login with OTP Instead',
          onTapButton: () => _onSelectMethod(LoginMethod.otp),
        );
      }
      return Column(
        children: [
          const SizedBox(height: 4),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: const Center(
              child: Icon(
                Icons.dialpad_rounded,
                size: 28,
                color: Color(0xFF7B3DC3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Device MPIN Login',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3F1A55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Enter your device PIN or pattern to sign in securely',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          _buildActionButton(
            label: _isLoading ? 'Authenticating...' : 'Enter Device MPIN',
            icon: Icons.dialpad_rounded,
            onTap: _isLoading
                ? null
                : () => _handleBiometricLogin(DeviceAuthMethod.deviceCredential),
          ),
          const SizedBox(height: 8),
          _buildOtherMethodLinks(LoginMethod.mpin),
        ],
      );
    }

    // ── First-time Registration Directly on this Tab ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: const Icon(
                Icons.dialpad_rounded,
                size: 18,
                color: Color(0xFF7B3DC3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Device MPIN Login',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3F1A55),
                    ),
                  ),
                  Text(
                    'Set up device PIN or pattern sign-in',
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildMobileInput(),
        if (_mobileError.isNotEmpty) _buildErrorText(_mobileError),
        _buildTermsCheckbox(),
        const SizedBox(height: 8),
        if (!_otpSent)
          _buildActionButton(
            label: _isLoading ? 'Sending Code...' : 'Register MPIN',
            icon: Icons.dialpad_rounded,
            onTap: (_isLoading ||
                    !_acceptedTerms ||
                    !_validateMobile(_mobileController.text))
                ? null
                : _handleSendOtp,
          )
        else
          _buildOtpInputSection(
            verifyButtonLabel: 'Verify & Activate MPIN',
            onVerify: () =>
                _handleRegisterDeviceAuth(DeviceAuthMethod.deviceCredential),
            extraNotice: 'Enter verification code to activate MPIN login',
          ),
        if (_otpMessage.isNotEmpty && _otpSent)
          _buildSuccessText(_otpMessage),
      ],
    );
  }

  // ── Action Button ──
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7B3DC3), Color(0xFF5537BE)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40B78AF3),
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Alternative Links ──
  Widget _buildOtherMethodLinks(LoginMethod current) {
    final entries = <MapEntry<String, VoidCallback>>[];
    if (current != LoginMethod.otp && _showOtpMethod) {
      entries.add(
        MapEntry('Login with OTP', () => _onSelectMethod(LoginMethod.otp)),
      );
    }
    if (current != LoginMethod.biometric && _showBiometricMethod) {
      entries.add(
        MapEntry(
          'Login with Biometrics',
          () => _onSelectMethod(LoginMethod.biometric),
        ),
      );
    }
    if (current != LoginMethod.mpin && _showMpinMethod) {
      entries.add(
        MapEntry('Login with MPIN', () => _onSelectMethod(LoginMethod.mpin)),
      );
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) {
        children.add(
          Text(
            '  •  ',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFFA1A1A1),
            ),
          ),
        );
      }
      children.add(
        GestureDetector(
          onTap: entries[i].value,
          child: Text(
            entries[i].key,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7C3AED),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
  }

  // ── Unavailable State ──
  Widget _buildUnavailableState({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTapButton,
    String? secondaryText,
    VoidCallback? onTapSecondary,
  }) {
    return Column(
      children: [
        const SizedBox(height: 6),
        const Icon(
          Icons.info_outline_rounded,
          size: 36,
          color: Color(0xFFD4650F),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3F1A55),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: buttonText,
          icon: Icons.arrow_forward_rounded,
          onTap: onTapButton,
        ),
        if (secondaryText != null && onTapSecondary != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTapSecondary,
            child: Text(
              secondaryText,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7C3AED),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    final link = GoogleFonts.poppins(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF7C3AED),
      decoration: TextDecoration.underline,
    );
    final body = GoogleFonts.poppins(
      fontSize: 12,
      height: 1.35,
      color: const Color(0xFF4E4E4E),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _acceptedTerms,
                  activeColor: const Color(0xFF7C3AED),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) => setState(() {
                    _acceptedTerms = value ?? false;
                    _termsError = '';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('I agree to the ', style: body),
                    GestureDetector(
                      onTap: () => context.push('/terms'),
                      child: Text('Terms & Conditions', style: link),
                    ),
                    Text(' and ', style: body),
                    GestureDetector(
                      onTap: () => context.push('/privacy'),
                      child: Text('Privacy Policy', style: link),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_termsError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 32),
              child: Text(
                _termsError,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFFB42318),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Mobile Input ──
  Widget _buildMobileInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9D9D9)),
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Country code prefix
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7FA),
                  border: Border(right: BorderSide(color: Color(0xFFEBEBEB))),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(13),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      '+91',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFFA1A1A1),
                    ),
                  ],
                ),
              ),
              // Mobile number input
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_otpSent,
                  onChanged: (_) => _clearErrors(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Enter mobile number',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      color: const Color(0xFFA6A4A4),
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (_otpSent)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _otpSent = false;
                        _otpMessage = '';
                        for (final c in _otpControllers) {
                          c.clear();
                        }
                      });
                    },
                    child: Text(
                      'Edit',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── OTP Section (Shared for Login and Direct Registration) ──
  Widget _buildOtpInputSection({
    required String verifyButtonLabel,
    required VoidCallback onVerify,
    String? extraNotice,
  }) {
    return Column(
      children: [
        // 4-digit OTP boxes
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
                child: TextField(
                    controller: _otpControllers[i],
                    focusNode: _otpFocusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    maxLength: 1,
                    maxLines: 1,
                    cursorHeight: 24,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC9C9C9)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF7C3AED),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC9C9C9)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) => _handleOtpInput(i, v),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
              ),
            );
          }),
        ),
        if (extraNotice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              extraNotice,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Action button
        GestureDetector(
          onTap: (_isLoading || !_validateOtp()) ? null : onVerify,
          child: Opacity(
            opacity: (!_validateOtp() || _isLoading) ? 0.5 : 1.0,
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7B3DC3), Color(0xFF5537BE)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40B78AF3),
                    blurRadius: 8,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLoading ? 'Processing...' : verifyButtonLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (!_isLoading) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Resend code link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't Receive? ",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF4E4E4E),
              ),
            ),
            GestureDetector(
              onTap: _handleSendOtp,
              child: Text(
                'Resend Code',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7C3AED),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Alert Widget ──
  Widget _buildAlert(String message, {bool isAmber = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAmber ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAmber
              ? const Color(0xFFFDE68A).withValues(alpha: 0.3)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAmber ? Icons.warning_amber_rounded : Icons.error_outline,
            size: 14,
            color: isAmber ? const Color(0xFFF59E0B) : Colors.red[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isAmber ? const Color(0xFF92400E) : Colors.red[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 9,
        color: Colors.red[500],
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _buildSuccessText(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      '✓ $text',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 9,
        color: const Color(0xFF16A34A),
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
