import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CorporateScreen extends StatefulWidget {
  const CorporateScreen({super.key});

  @override
  State<CorporateScreen> createState() => _CorporateScreenState();
}

class _CorporateScreenState extends State<CorporateScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _employeeCountController = TextEditingController();
  bool _showContactModal = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _employeeCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
                color: Colors.white,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
                    ),
                    const Spacer(),
                    const Text('Corporate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6C5CE7)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business, size: 60, color: Colors.white),
                            SizedBox(height: 12),
                            Text('Corporate Gifting', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildHighlightChip(Icons.groups, 'Bulk Discounts', const Color(0xFFEEF2FF)),
                          _buildHighlightChip(Icons.receipt_long, 'GST Invoice', const Color(0xFFFEF3C7)),
                          _buildHighlightChip(Icons.auto_awesome, 'Custom Branding', const Color(0xFFE9FBF1)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildStep(1, 'Submit Corporate Inquiry', 'Fill out the contact form with your company details and requirements.', Icons.description, const Color(0xFF6C5CE7), hasAction: true),
                      _buildStep(2, 'Receive Custom Pricing', 'Our team will reach out with customized corporate pricing.', Icons.monetization_on, const Color(0xFF3B82F6)),
                      _buildStep(3, 'Select Vouchers', 'Choose from premium brands and select denominations.', Icons.card_giftcard, const Color(0xFFEC4899)),
                      _buildStep(4, 'Bulk Order Placement', 'Place your corporate order with employee details.', Icons.shopping_basket, const Color(0xFF4C42B8)),
                      _buildStep(5, 'Instant Delivery', 'Vouchers delivered to your dashboard for distribution.', Icons.send, const Color(0xFF6C5CE7)),
                      _buildStep(6, 'Track Redemption', 'Monitor voucher usage with detailed analytics.', Icons.analytics, const Color(0xFFF97316)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showContactModal)
            GestureDetector(
              onTap: () => setState(() => _showContactModal = false),
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Contact Us', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Corporate Gifting Inquiry', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            _buildTextField('Full Name', _nameController),
                            const SizedBox(height: 12),
                            _buildTextField('Work Email', _emailController),
                            const SizedBox(height: 12),
                            _buildTextField('Phone', _phoneController),
                            const SizedBox(height: 12),
                            _buildTextField('Company Name', _companyController),
                            const SizedBox(height: 12),
                            _buildTextField('Employee Count', _employeeCountController),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => setState(() => _showContactModal = false),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                                child: const Text('Submit Inquiry'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightChip(IconData icon, String text, Color bg) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildStep(int id, String title, String description, IconData icon, Color color, {bool hasAction = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (hasAction) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showContactModal = true),
                    child: const Text('Click here to proceed →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }
}
