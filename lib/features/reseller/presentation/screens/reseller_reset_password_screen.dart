import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/reseller/data/reseller_api.dart';
import 'package:gift360/features/reseller/presentation/providers/reseller_provider.dart';

/// Target of the forgot-password email link: `/changepassword?token=...`
/// Enter + re-enter the new password -> POST /auth/reset-password.
class ResellerResetPasswordScreen extends ConsumerStatefulWidget {
  final String? token;

  const ResellerResetPasswordScreen({super.key, this.token});

  @override
  ConsumerState<ResellerResetPasswordScreen> createState() =>
      _ResellerResetPasswordScreenState();
}

class _ResellerResetPasswordScreenState
    extends ConsumerState<ResellerResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.token ?? '';
    final password = _password.text;
    final confirm = _confirm.text;
    if (password.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match - enter the same password in both fields');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(resellerApiProvider).resetPassword(token, password);
      if (data['success'] == true) {
        setState(() => _done = true);
      } else {
        setState(() => _error =
            (data['message'] ?? "Couldn't reset the password. Please retry.").toString());
      }
    } catch (e) {
      setState(() => _error =
          ResellerApi.errorMessage(e, 'This reset link is invalid or has expired.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = (widget.token ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => context.go('/reseller'),
        ),
        title: Text(
          'Change password',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: !hasToken
              ? Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Missing reset link',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open the link from your email, or request a new one from the login screen.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/reseller/login'),
                      child: const Text('Go to login'),
                    ),
                  ],
                )
              : _done
                  ? Column(
                      children: [
                        const Icon(Icons.check_circle, size: 48, color: Color(0xFF16A34A)),
                        const SizedBox(height: 12),
                        Text(
                          'Password changed',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in with your new password.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.go('/reseller/login'),
                          child: const Text('Sign in'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Set a new password',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirm,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Re-enter password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF523DA9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Change password'),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
