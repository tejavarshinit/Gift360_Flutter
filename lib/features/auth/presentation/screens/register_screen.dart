import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/constants/app_constants.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String _error = '';
  String _nameError = '';
  String _emailError = '';
  String _mobileError = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _mobileController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool valid = true;
    setState(() {
      _error = '';
      _nameError = '';
      _emailError = '';
      _mobileError = '';
    });
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required');
      valid = false;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!AppConstants.emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      valid = false;
    }
    if (_mobileController.text.trim().isEmpty) {
      setState(() => _mobileError = 'Mobile number is required');
      valid = false;
    } else if (!AppConstants.mobileRegex.hasMatch(_mobileController.text.trim())) {
      setState(() => _mobileError = 'Please enter a valid 10-digit mobile number');
      valid = false;
    }
    return valid;
  }

  Future<void> _sendOtp() async {
    if (!_validateForm()) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await ref.read(authProvider.notifier).registerSendOtp(
        mobileNumber: _mobileController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (response.success) {
        setState(() {
          _otpSent = true;
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
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (!AppConstants.otpRegex.hasMatch(_otpController.text.trim())) {
      setState(() => _error = 'Please enter a valid 4-6 digit OTP');
      return;
    }
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await ref.read(authProvider.notifier).registerVerifyOtp(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        otp: _otpController.text.trim(),
      );

      if (response.success && response.token != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to Gift360!'),
              backgroundColor: AppColors.success,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) context.go('/');
        }
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8D7FF), Colors.white],
                ),
              ),
            ),
          ),
          _auroraBlob(
            top: -40,
            left: -40,
            size: 288,
            color: const Color(0xFFB83DF5),
            alpha: 0.22,
          ),
          _auroraBlob(
            top: 128,
            right: -64,
            size: 320,
            color: const Color(0xFF256AF4),
            alpha: 0.18,
          ),
          _auroraBlob(
            bottom: 80,
            left: MediaQuery.of(context).size.width * 0.25,
            size: 224,
            color: AppColors.gold,
            alpha: 0.14,
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/Gift.png',
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      Transform.translate(
                        offset: const Offset(-32, 6),
                        child: Image.asset(
                          'assets/images/G word.png',
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Join Gift360 today',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.purpleLight,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
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
                            const Icon(Icons.auto_awesome, size: 16, color: AppColors.goldLight),
                            const SizedBox(width: 8),
                            const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
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
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error, style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),

                        _buildLabel('FULL NAME'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _nameController,
                          hint: 'Enter your full name',
                          enabled: !_otpSent,
                          prefixIcon: Icons.person_outline,
                        ),
                        if (_nameError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_nameError, style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500)),
                          ),
                        const SizedBox(height: 16),

                        _buildLabel('EMAIL'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_otpSent,
                          prefixIcon: Icons.email_outlined,
                        ),
                        if (_emailError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_emailError, style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500)),
                          ),
                        const SizedBox(height: 16),

                        _buildLabel('MOBILE NUMBER'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _mobileController,
                                hint: '10-digit number',
                                keyboardType: TextInputType.phone,
                                enabled: !_otpSent,
                                prefixWidget: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.smartphone, size: 20, color: AppColors.goldLight.withValues(alpha: 0.8)),
                                    const SizedBox(width: 4),
                                    const Text('+91', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSendOtpButton(),
                          ],
                        ),
                        if (_mobileError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_mobileError, style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500)),
                          ),
                        if (_otpSent && _mobileError.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                const SizedBox(width: 4),
                                const Text('OTP sent successfully', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),

                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          _buildLabel('ENTER OTP'),
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

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'By creating an account, you agree to our Terms and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.7),
        letterSpacing: 1.2,
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
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        maxLength: maxLength,
        textAlign: textAlign ?? TextAlign.start,
        autofillHints: const [],
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: letterSpacing ?? 0,
        ),
        decoration: InputDecoration(
          filled: false,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w400),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: prefixWidget ??
              (prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.goldLight.withValues(alpha: 0.8)) : null),
        ),
      ),
    );
  }

  Widget _buildSendOtpButton() {
    final isValid = AppConstants.mobileRegex.hasMatch(_mobileController.text) &&
        AppConstants.emailRegex.hasMatch(_emailController.text) &&
        _nameController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: (_isLoading || _otpSent || !isValid) ? null : _sendOtp,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: _otpSent
              ? null
              : const LinearGradient(colors: [AppColors.gold, AppColors.goldLight]),
          color: _otpSent ? AppColors.success.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(16),
          border: _otpSent ? Border.all(color: AppColors.success.withValues(alpha: 0.4)) : null,
          boxShadow: _otpSent
              ? null
              : [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            _isLoading ? 'Sending...' : _otpSent ? '✓ Sent' : 'Send OTP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _otpSent ? AppColors.success : const Color(0xFF1A0D00),
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
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldLight]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A0D00))),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Color(0xFF1A0D00)),
          ],
        ),
      ),
    );
  }
}
