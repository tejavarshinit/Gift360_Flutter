import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String _error = '';
  String _passwordError = '';
  bool _success = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _validatePassword(String p) {
    if (p.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Password must contain at least one uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(p)) return 'Password must contain at least one lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(p)) return 'Password must contain at least one number';
    return '';
  }

  Future<void> _handleSubmit() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() => _error = '');

    if (newPassword.isEmpty) {
      setState(() => _error = 'Password is required');
      return;
    }
    final validation = _validatePassword(newPassword);
    if (validation.isNotEmpty) {
      setState(() => _error = validation);
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    // Get token from route query params
    final uri = Uri.base;
    final token = uri.queryParameters['token'] ?? '';

    if (token.isEmpty) {
      setState(() => _error = 'Invalid reset link');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authApi = ref.read(authApiProvider);
      final response = await authApi.resetPassword(token, newPassword);
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
        // Redirect to login after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) context.go('/login');
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
                      child: Icon(
                        _success ? Icons.check_circle_rounded : Icons.key_rounded,
                        size: 36,
                        color: AppColors.goldLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.gold, AppColors.goldLight],
                      ).createShader(bounds),
                      child: Text(
                        _success ? 'Password Reset!' : 'Reset Your Password',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _success ? 'Your password has been updated' : 'Enter your new password below',
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
            const Text('New Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
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

        // New Password
        Text('NEW PASSWORD',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.2)),
        const SizedBox(height: 6),
        _buildPasswordField(
          controller: _newPasswordController,
          hint: 'Enter new password',
          showPassword: _showNewPassword,
          onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
          prefixIcon: Icons.key_rounded,
        ),
        if (_passwordError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_passwordError, style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Must be at least 8 characters with uppercase, lowercase, and numbers',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password
        Text('CONFIRM PASSWORD',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.2)),
        const SizedBox(height: 6),
        _buildPasswordField(
          controller: _confirmPasswordController,
          hint: 'Confirm new password',
          showPassword: _showConfirmPassword,
          onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: (_isLoading || _newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty)
              ? null
              : _handleSubmit,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldLight]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Text(
                _isLoading ? 'Resetting Password...' : 'Reset Password',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A0D00)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: () => context.go('/login'),
          child: Center(
            child: Text(
              'Back to Login',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.goldLight.withValues(alpha: 0.8)),
            ),
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
        const Text('Password Reset Successfully!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          'Redirecting you to login...',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
    required IconData prefixIcon,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: !showPassword,
        enabled: !_isLoading,
        autofillHints: const [],
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        onChanged: (v) {
          setState(() => _error = '');
          _passwordError = _validatePassword(v);
        },
        decoration: InputDecoration(
          filled: false,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.goldLight.withValues(alpha: 0.8)),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
