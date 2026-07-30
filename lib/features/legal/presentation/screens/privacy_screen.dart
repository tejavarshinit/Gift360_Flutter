import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Privacy Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('1. Purpose', [
              'This Privacy Policy explains how Gift360 collects, uses, shares, stores, and protects information when you purchase or redeem a Gift Voucher.',
              'The policy complies with Digital Personal Data Protection (DPDP) Act, 2023, Information Technology Act, 2000 & SPDI Rules, and RBI PPI Guidelines.',
            ]),
            _section('2. Data We Collect', [
              'Personal Information: Name, Mobile number, Email address, Billing address, Payment method details, KYC information.',
              'Voucher Information: Voucher ID, value, issuance date, Redemption logs, Transaction metadata.',
              'Device & Technical Data: IP address, Browser/device identifiers, Cookies, Usage analytics.',
            ]),
            _section('3. How We Use Your Data', [
              'Issue and deliver vouchers',
              'Verify identity and prevent fraud',
              'Process transactions and redemption',
              'Provide customer support',
              'Send updates, alerts, and promotional messages',
              'Improve our platform and security',
            ]),
            _section('4. Sharing of Information', [
              'Payment aggregators, banks, card networks',
              'Partner merchants (if redeemable externally)',
              'SMS/email service providers',
              'Regulatory bodies when required',
              'We do not sell personal data.',
            ]),
            _section('5. Data Security Measures', [
              'Encryption of sensitive data',
              'Secure storage systems',
              'Access control and authentication',
              'Regular audits and monitoring for fraud',
            ]),
            _section('6. Your Rights (DPDP Act)', [
              'Access personal data',
              'Correct inaccurate data',
              'Delete personal data (where permitted)',
              'Withdraw consent',
              'Request grievance redressal',
            ]),
            _section('7. Contact Details', [
              'Data Protection Officer (DPO)\nOne78 SabbPe Technology Solutions India Private Limited\nEmail: contact@gift360.io',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...points.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
          )),
        ],
      ),
    );
  }
}
