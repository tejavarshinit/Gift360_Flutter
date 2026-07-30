import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RefundScreen extends StatelessWidget {
  const RefundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Refund & Cancellation Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('1. General Refund Principles', [
              'Refunds are governed by RBI PPI rules and Gift360 internal policies.',
              'Refunds are provided only in exceptional cases.',
              'Once a voucher is issued/activated, a refund is generally not possible unless mandated by law.',
            ]),
            _section('2. Refund Eligibility Scenarios', [
              'a) Technical Errors: Platform malfunction or system error leads to duplicate charges. Voucher codes not being generated/delivered after successful payment.',
              'b) Payment Issues: Payment debited but voucher not issued within 24-48 hours. Unintended multiple debits.',
              'c) Voucher Activation Errors: Voucher cannot be redeemed due to platform or brand-end technical issues.',
            ]),
            _section('3. Non-Refundable Situations', [
              'Change of mind after purchase',
              'Partial use of a voucher',
              'Voucher already activated/redeemed',
              'Expired vouchers (unless technical error is proven)',
              'Loss or theft of voucher code',
            ]),
            _section('4. Refund Process', [
              'Step 1: Submit refund request via email or in-app support within 7 days of purchase with transaction ID and proof of payment.',
              'Step 2: Gift360 team reviews the request within 5-7 business days.',
              'Step 3: If approved, refund will be processed to the original payment method within 7-14 business days.',
            ]),
            _section('5. Cancellation Policy', [
              'Orders can only be cancelled before voucher generation/activation.',
              'Post-activation, cancellation is not possible unless there\'s a technical error.',
              'For bulk orders, cancellation must be requested within 24 hours of order placement.',
            ]),
            _section('6. Contact for Refund Queries', [
              'Email: support@gift360.io',
              'Support Hours: Mon-Sat, 9:00 AM - 6:00 PM IST',
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
