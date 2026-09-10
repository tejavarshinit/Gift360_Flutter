import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/constants/app_constants.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String _otpMessage = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileController.text.trim();
    if (!AppConstants.mobileRegex.hasMatch(mobile)) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _otpMessage = '';
      _otpSent = false;
    });

    try {
      final response = await ref.read(authProvider.notifier).sendOtp(
        SendOtpRequest(
          mobileNumber: mobile,
          email: _emailController.text.trim(),
        ),
      );

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final mobile = _mobileController.text.trim();
    final otp = _otpController.text.trim();

    if (!AppConstants.mobileRegex.hasMatch(mobile)) {
      setState(() => _error = 'Please enter a valid mobile number');
      return;
    }
    if (!AppConstants.otpRegex.hasMatch(otp)) {
      setState(() => _error = 'Please enter a valid OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await ref.read(authProvider.notifier).loginWithOtp(
        LoginWithOtpRequest(
          mobileNumber: mobile,
          otp: otp,
          email: _emailController.text.trim(),
        ),
      );

      if (response.success && response.token != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back!'),
              backgroundColor: AppColors.success,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) context.go('/');
        }
      } else {
        setState(() {
          _error = response.message.isNotEmpty
              ? response.message
              : 'OTP verification failed';
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

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('connection error') || msg.contains('No internet') || msg.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('connection timeout') || msg.contains('receive timeout')) {
      return 'Connection timed out. Please try again.';
    }
    if (msg.contains('404')) return 'Service not found. Please try again later.';
    if (msg.contains('500')) return 'Server error. Please try again later.';
    if (msg.contains('401') || msg.contains('403')) return 'Session expired. Please try again.';
    if (msg.length > 120) return 'Something went wrong. Please try again.';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/ganeshauth.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).size.height * 0.42, 20, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 16, color: AppColors.goldLight),
                            const SizedBox(width: 8),
                            const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                            color: const Color(0xFF351265),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'MOBILE NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF625A70),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _mobileController,
                                hint: '10-digit mobile',
                                keyboardType: TextInputType.phone,
                                enabled: !_otpSent,
                                prefixWidget: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.smartphone,
                                        size: 20,
                                        color: AppColors.goldLight.withValues(alpha: 0.8)),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '+91',
                                      style: TextStyle(
                                        color: const Color(0xFF24184B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSendOtpButton(),
                          ],
                        ),
                        if (_otpSent && _otpMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '✓ $_otpMessage',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          Text(
                            'ENTER OTP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF625A70),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _otpController,
                                  hint: '• • • • • •',
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  letterSpacing: 6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildVerifyButton(),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'By continuing, you agree to our Terms and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _auroraBlob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
    double alpha = 0.30,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool enabled = true,
    int? maxLength,
    TextAlign? textAlign,
    double? letterSpacing,
    IconData? prefixIcon,
    Widget? prefixWidget,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDFDBE3)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        maxLength: maxLength,
        textAlign: textAlign ?? TextAlign.start,
        autofillHints: const [],
        style: TextStyle(
          color: const Color(0xFF24184B),
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: letterSpacing ?? 0,
        ),
        decoration: InputDecoration(
          filled: false,
          hintText: hint,
          hintStyle: TextStyle(
            color: const Color(0xFF9C96A6),
            fontWeight: FontWeight.w400,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: prefixWidget ??
              (prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: AppColors.goldLight)
                  : null),
        ),
      ),
    );
  }

  Widget _buildSendOtpButton() {
    final isValid = AppConstants.mobileRegex.hasMatch(_mobileController.text);
    return GestureDetector(
      onTap: (_isLoading || _otpSent || !isValid) ? null : _sendOtp,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: _otpSent
              ? null
              : const LinearGradient(
                  colors: [AppColors.gold, AppColors.goldLight],
                ),
          color: _otpSent ? AppColors.success.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(16),
          border: _otpSent
              ? Border.all(color: AppColors.success.withValues(alpha: 0.4))
              : null,
          boxShadow: _otpSent
              ? null
              : [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            _isLoading ? 'Sending...' : _otpSent ? '✓ Sent' : 'Send OTP',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _otpSent
                  ? AppColors.success
                  : const Color(0xFF1A0D00),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isValid = AppConstants.otpRegex.hasMatch(_otpController.text);
    return GestureDetector(
      onTap: (_isLoading || !isValid) ? null : _verifyOtp,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gold, AppColors.goldLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Verify',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A0D00),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Color(0xFF1A0D00)),
          ],
        ),
      ),
    );
  }
}
