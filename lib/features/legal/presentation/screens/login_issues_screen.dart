import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// `/login-issues` — Help Center article (ported from React `LoginIssues.tsx`).
class LoginIssuesScreen extends StatelessWidget {
  const LoginIssuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/faq');
                      }
                    },
                    icon: const Icon(Icons.chevron_left, size: 26),
                  ),
                  Text(
                    'Login & Access Issues',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Having trouble logging in? Don't worry — we're here to help you get back to your vouchers quickly.",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.5,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _section(
                        '1. Troubleshooting OTP Issues',
                        bullets: [
                          'Wait for at least 60 seconds before requesting a "Resend".',
                          'Check if your mobile network is stable.',
                          "Ensure you haven't blocked SMS from unknown senders in your phone settings.",
                          'Verify that you entered the correct mobile number.',
                        ],
                      ),
                      const SizedBox(height: 16),
                      _section(
                        '2. "Account Locked" Error',
                        body:
                            'As a security measure, accounts are temporarily locked after 5 failed login attempts. Please wait for 30 minutes before trying again, or use the "Forgot Password" link to reset your access.',
                      ),
                      const SizedBox(height: 16),
                      _section(
                        '3. Browser Compatibility',
                        body:
                            'Ensure you are using the latest version of your browser. We recommend Google Chrome or Safari for the best experience. Sometimes, clearing your browser cache/cookies can solve persistent login bugs.',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push('/forgot-password'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C3AED),
                                side: const BorderSide(
                                  color: Color(0xFF7C3AED),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Reset Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => context.push('/faq'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9747FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Contact Support',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, {String? body, List<String>? bullets}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (body != null)
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.5,
              color: const Color(0xFF374151),
            ),
          ),
        if (bullets != null)
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: Color(0xFF7C3AED))),
                  Expanded(
                    child: Text(
                      b,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.5,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
