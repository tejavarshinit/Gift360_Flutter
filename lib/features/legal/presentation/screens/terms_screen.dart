import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Terms & Conditions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Introduction', [
              'These Terms & Conditions govern the purchase, issuance, use, redemption, cancellation, refund, and expiry of Gift360 Gift Vouchers. The Vouchers are issued by: One78 SabbPe Technology Solutions India Private Limited.',
            ]),
            _section('Nature of the Voucher', [
              'Gift360 Gift Vouchers are prepaid instruments, redeemable only for products/services listed on the Gift360 platform or approved partner platforms.',
              'Vouchers do not carry any interest.',
              'Vouchers are not legal tender, not transferable for cash, and not reloadable unless explicitly stated.',
            ]),
            _section('Eligibility', [
              'Be at least 18 years old',
              'Have a valid Indian mobile number or email',
              'Be legally capable of entering into a contract under the Indian Contract Act, 1872',
            ]),
            _section('Validity Period', [
              'All vouchers have a minimum 1-year validity from the date of issuance (as per RBI PPI norms).',
              'Expiry date will be explicitly mentioned.',
            ]),
            _section('Redemption Conditions', [
              'Vouchers can be redeemed only against eligible goods/services listed on the Gift360 platform.',
              'Partial Redemption: If allowed, any unused balance remains available until the expiry date.',
            ]),
            _section('Non-Transferability', [
              'Vouchers cannot be resold, transferred (unless explicitly allowed), bartered, or converted to cash or credit.',
            ]),
            _section('Cancellation by User', [
              'Once issued/activated, vouchers generally cannot be cancelled.',
              'Pre-issuance cancellation may be allowed (see Refund Policy).',
            ]),
            _section('Limitation of Liability', [
              'Gift360 is not liable for loss arising from voucher misuse, inability to redeem due to technical issues, merchant non-performance, or loss of data.',
            ]),
            _section('Governing Law & Jurisdiction', [
              'These Terms are governed by Indian law. Legal disputes shall be subject to courts having jurisdiction where Gift360\'s registered office is located.',
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
