import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DistributorScreen extends StatefulWidget {
  const DistributorScreen({super.key});

  @override
  State<DistributorScreen> createState() => _DistributorScreenState();
}

class _DistributorScreenState extends State<DistributorScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  bool _showContactModal = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
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
              // Nav bar
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
                    const Text('Distributor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      // Hero placeholder
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF523DA9)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront, size: 60, color: Colors.white),
                            SizedBox(height: 12),
                            Text('Become a Distributor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Highlights
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildHighlightChip(Icons.local_offer, 'Bulk Offers', const Color(0xFFEEF2FF)),
                          _buildHighlightChip(Icons.auto_awesome, 'Attractive Discounts', const Color(0xFFFFECEC)),
                          _buildHighlightChip(Icons.trending_up, 'Priority Processing', const Color(0xFFE9FBF1)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Steps
                      _buildStep(1, 'Submit Distributor Registration', 'Register your organization to apply for distributor pricing access.', Icons.person_add, const Color(0xFF6C5CE7), hasAction: true),
                      _buildStep(2, 'Receive Distributor ID & Unlock Pricing', 'Once approved, receive your Distributor Registration ID via email.', Icons.mail_outline, const Color(0xFF4C42B8)),
                      _buildStep(3, 'Select Discount / Denomination', 'Pick discount & value', Icons.tag, const Color(0xFFEC4899)),
                      _buildStep(4, 'Add to Cart', 'Review & confirm quantity', Icons.shopping_cart_outlined, const Color(0xFF3B82F6)),
                      _buildStep(5, 'Make Payment', 'Secure & fast checkout', Icons.credit_card, const Color(0xFF6C5CE7)),
                      _buildStep(6, 'Receive Multiple Voucher Orders', 'Instant delivery to your dashboard', Icons.mark_email_read, const Color(0xFFF97316)),
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Contact Us', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Register as a Distributor', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            _buildTextField('Full Name', _nameController),
                            const SizedBox(height: 12),
                            _buildTextField('Email', _emailController),
                            const SizedBox(height: 12),
                            _buildTextField('Phone', _phoneController),
                            const SizedBox(height: 12),
                            _buildTextField('Company Name', _companyController),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => setState(() => _showContactModal = false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C5CE7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Submit Registration'),
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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
