import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BulkPurchaseScreen extends StatelessWidget {
  const BulkPurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Bulk Purchase & Corporate Gifting', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Bulk Purchase & Corporate Gifting', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Whether you\'re looking to reward your employees or surprise your clients, Gift360 offers a robust platform for bulk gift voucher purchases with exclusive benefits.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
            ),
            const SizedBox(height: 24),

            _buildSection('1. Benefits of Bulk Orders', [
              'Special corporate discounts on top brands.',
              'Dedicated account manager for seamless coordination.',
              'Customized branding options for your delivery messages.',
              'Bulk delivery via Excel/CSV uploads.',
            ]),
            const SizedBox(height: 20),
            _buildSection('2. How to place a bulk order?', [
              'Currently, we handle bulk orders through our corporate sales team. You can initiate a request by clicking the "Drop a Query" button on the FAQ page and selecting "Bulk Purchase" as the topic.',
            ]),
            const SizedBox(height: 20),
            _buildSection('3. Delivery Timelines', [
              'While individual orders are instant, bulk orders may take 2-4 business hours for processing and security checks before deployment.',
            ]),
            const SizedBox(height: 24),

            // CTA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Text('Ready to power your rewards?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Contact Sales Team'),
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

  Widget _buildSection(String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...points.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
              Expanded(child: Text(p, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5))),
            ],
          ),
        )),
      ],
    );
  }
}
