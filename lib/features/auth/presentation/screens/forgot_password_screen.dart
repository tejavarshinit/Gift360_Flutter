import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/constants/app_constants.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  bool _success = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email address is required');
      return;
    }
    if (!AppConstants.emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authApi = ref.read(authApiProvider);
      final response = await authApi.forgotPassword(email);
      setState(() {
        _success = true;
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF523DA9), Color(0xFF4C42B8), Color(0xFF5365DF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40, left: -40,
            child: Container(
              width: 288, height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF523DA9).withValues(alpha: 0.55), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            top: 128, right: -64,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF4C42B8).withValues(alpha: 0.5), Colors.transparent]),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Branding
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.8), blurRadius: 8, spreadRadius: 1)],
                      ),
                      child: const Icon(Icons.key_rounded, size: 36, color: AppColors.goldLight),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.gold, AppColors.goldLight],
                      ).createShader(bounds),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No worries — we\'ll send you reset instructions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 28),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: _success ? _buildSuccessView() : _buildFormView(),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Didn\'t receive the email? Check your spam folder',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.goldLight),
            const SizedBox(width: 8),
            const Text('Reset Your Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
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
                Expanded(child: Text(_error, style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500))),
              ],
            ),
          ),

        Text('EMAIL ADDRESS',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            autofillHints: const [],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              filled: false,
              hintText: 'Enter your email address',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.goldLight.withValues(alpha: 0.8)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: _isLoading ? null : _handleSubmit,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldLight]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Text(
                _isLoading ? 'Sending...' : 'Send Reset Link',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A0D00)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: () => context.go('/login'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 16, color: AppColors.goldLight.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                'Back to Login',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.goldLight.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.check_circle_rounded, size: 32, color: AppColors.success),
        ),
        const SizedBox(height: 16),
        const Text('Check Your Email', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
            children: [
              const TextSpan(text: 'We\'ve sent a password reset link to '),
              TextSpan(
                text: _emailController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.goldLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The link will expire in 30 minutes for security reasons',
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => context.go('/login'),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldLight]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, size: 18, color: Color(0xFF1A0D00)),
                SizedBox(width: 8),
                Text('Back to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A0D00))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
